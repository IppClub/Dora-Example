static std::optional<std::string> gzip_decompress(std::string_view content) {
	z_stream stream{};
	if (inflateInit2(&stream, MAX_WBITS + 16) != Z_OK) return std::nullopt;
	std::string decompressed;
	std::array<unsigned char, 64 * 1024> buffer{};
	size_t offset = 0;
	int result = Z_OK;
	while (result != Z_STREAM_END) {
		if (stream.avail_in == 0 && offset < content.size()) {
			auto length = std::min(content.size() - offset, s_cast<size_t>(std::numeric_limits<uInt>::max()));
			stream.next_in = r_cast<Bytef*>(const_cast<char*>(content.data() + offset));
			stream.avail_in = s_cast<uInt>(length);
			offset += length;
		}
		stream.next_out = buffer.data();
		stream.avail_out = s_cast<uInt>(buffer.size());
		result = inflate(&stream, Z_NO_FLUSH);
		if (result != Z_OK && result != Z_STREAM_END) {
			inflateEnd(&stream);
			return std::nullopt;
		}
		decompressed.append(r_cast<const char*>(buffer.data()), buffer.size() - stream.avail_out);
	}
	inflateEnd(&stream);
	return decompressed;
}

DORA_TEST_ENTRY(HttpCompressionCpp) {
	auto check = [](bool condition, String message) {
		if (!condition) LogError(fmt::format("HttpCompressionCpp: {}", message.toString()));
		return condition;
	};
	bool passed = true;
	passed &= check(is_compressible_content_type("text/javascript; charset=utf-8"sv), "JavaScript should be compressible"_slice);
	passed &= check(is_compressible_content_type("application/json"sv), "JSON should be compressible"_slice);
	passed &= check(is_compressible_content_type("image/svg+xml"sv), "SVG should be compressible"_slice);
	passed &= check(!is_compressible_content_type("text/event-stream"sv), "event streams should not be compressed"_slice);
	passed &= check(!is_compressible_content_type("image/png"sv), "PNG should not be compressed"_slice);
	passed &= check(!is_compressible_content_type("application/wasm"sv), "Wasm should not be compressed"_slice);

	passed &= check(accepts_gzip_header("gzip"sv), "gzip token should be accepted"_slice);
	passed &= check(accepts_gzip_header("br, GZip; q=0.5"sv), "gzip token matching should ignore case"_slice);
	passed &= check(accepts_gzip_header("br; q=1, *; q=0.25"sv), "positive wildcard should accept gzip"_slice);
	passed &= check(!accepts_gzip_header("gzip; q=0"sv), "q=0 should reject gzip"_slice);
	passed &= check(!accepts_gzip_header("*;q=1, gzip;q=0"sv), "explicit gzip rejection should override wildcard"_slice);
	passed &= check(!accepts_gzip_header("gzip;q=invalid"sv), "invalid gzip quality should be rejected"_slice);
	passed &= check(!accepts_gzip_header("br, deflate"sv), "unsupported encodings should not enable gzip"_slice);

	std::string original;
	for (int i = 0; i < 4096; ++i) original += "Dora SSR xrt gzip response test.\n";
	auto compressed = gzip_compress(original);
	passed &= check(compressed.has_value(), "gzip compression should succeed"_slice);
	if (compressed) {
		passed &= check(compressed->size() < original.size(), "compressible data should become smaller"_slice);
		passed &= check(compressed->size() >= 2 && s_cast<unsigned char>((*compressed)[0]) == 0x1f && s_cast<unsigned char>((*compressed)[1]) == 0x8b, "output should have a gzip header"_slice);
		auto decompressed = gzip_decompress(*compressed);
		passed &= check(decompressed && *decompressed == original, "gzip output should round-trip exactly"_slice);
	}

	HttpServer::Response jsonResponse;
	jsonResponse.contentType = "application/json; charset=utf-8";
	jsonResponse.content = original;
	auto preparedJson = prepare_dynamic_response(std::move(jsonResponse), true);
	passed &= check(preparedJson.varyAcceptEncoding, "compressible dynamic responses should vary on Accept-Encoding"_slice);
	passed &= check(preparedJson.gzipEncoded, "large JSON dynamic responses should be gzip encoded"_slice);
	if (preparedJson.gzipEncoded) {
		auto decompressed = gzip_decompress(preparedJson.response.content);
		passed &= check(decompressed && *decompressed == original, "dynamic JSON gzip output should round-trip exactly"_slice);
	}

	HttpServer::Response identityResponse;
	identityResponse.contentType = "application/json";
	identityResponse.content = original;
	auto preparedIdentity = prepare_dynamic_response(std::move(identityResponse), false);
	passed &= check(preparedIdentity.varyAcceptEncoding, "identity JSON responses should still vary on Accept-Encoding"_slice);
	passed &= check(!preparedIdentity.gzipEncoded && preparedIdentity.response.content == original, "clients without gzip support should receive the original response"_slice);

	HttpServer::Response smallResponse;
	smallResponse.contentType = "text/plain; charset=utf-8";
	smallResponse.content = "small response";
	auto preparedSmall = prepare_dynamic_response(std::move(smallResponse), true);
	passed &= check(preparedSmall.varyAcceptEncoding, "small text responses should still vary on Accept-Encoding"_slice);
	passed &= check(!preparedSmall.gzipEncoded && preparedSmall.response.content == "small response", "small dynamic responses should stay uncompressed"_slice);

	HttpServer::Response binaryResponse;
	binaryResponse.contentType = "image/png";
	binaryResponse.content.assign(DynamicResponseCompressionThreshold * 2, '\0');
	auto preparedBinary = prepare_dynamic_response(std::move(binaryResponse), true);
	passed &= check(!preparedBinary.varyAcceptEncoding, "binary dynamic responses should not vary on Accept-Encoding"_slice);
	passed &= check(!preparedBinary.gzipEncoded, "binary dynamic responses should not be gzip encoded"_slice);
	return passed;
}

DORA_TEST_ENTRY(HttpAuthBodyHashCpp) {
	auto check = [](bool condition, String message) {
		if (!condition) LogError(fmt::format("HttpAuthBodyHashCpp: {}", message.toString()));
		return condition;
	};
	bool passed = true;

	std::string multipartType = "Multipart/Form-Data; boundary=generated-by-browser";
	std::string multipartBody = "--generated-by-browser\r\nContent-Disposition: form-data; name=\"file\"\r\n\r\npayload";
	HttpServer::Request multipartRequest;
	multipartRequest.contentType = multipartType;
	multipartRequest.body = multipartBody;
	passed &= check(auth_body_hash(multipartRequest).empty(), "multipart uploads should use the Web IDE empty body hash"_slice);

	std::string jsonType = "application/json";
	std::string jsonBody = R"({"value":1})";
	HttpServer::Request jsonRequest;
	jsonRequest.contentType = jsonType;
	jsonRequest.body = jsonBody;
	passed &= check(auth_body_hash(jsonRequest) == sha256_hex(jsonBody), "non-multipart requests should hash their actual body"_slice);

	return passed;
}

DORA_TEST_ENTRY(HttpStreamAbortCloseCpp) {
	const auto passed = DoraXrtHttpAbortCloseFallbackTest() != 0;
	if (!passed) {
		LogError("HttpStreamAbortCloseCpp: abort close did not resolve the request future");
	}
	return passed;
}
