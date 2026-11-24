// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>
#include <fstream>
#include <memory>
#include <string>
#include <utility>

template <class T>
using OwnArray = std::unique_ptr<T[]>;

struct String : std::string {
 using std::string::string;
 std::string toString() const { return *this; }
};

// The focused test compiles the production reader and substitutes only the
// platform file handle and Content resolver.
using SDL_RWops = std::ifstream;
inline constexpr auto RW_SEEK_SET = std::ios::beg;

inline int SDL_RWclose(SDL_RWops* file) {
 delete file;
 return 0;
}

inline int64_t SDL_RWsize(SDL_RWops* file) {
 file->seekg(0, std::ios::end);
 const auto size = file->tellg();
 file->seekg(0, std::ios::beg);
 return size;
}

inline int64_t SDL_RWseek(SDL_RWops* file, int64_t offset, std::ios::seekdir origin) {
 file->clear();
 file->seekg(offset, origin);
 return file->tellg();
}

inline size_t SDL_RWread(SDL_RWops* file, void* buffer, size_t size, size_t count) {
 file->read(static_cast<char*>(buffer), size * count);
 return static_cast<size_t>(file->gcount()) / size;
}

inline struct VideoContent {
 SDL_RWops* openReadFile(const String& name) {
  if (usePackage) return nullptr;
  auto file = std::make_unique<SDL_RWops>(name, std::ios::binary);
  return *file ? file.release() : nullptr;
 }
 std::pair<OwnArray<uint8_t>, size_t> load(const String& name) {
  if (!usePackage) return {};
  SDL_RWops file(name, std::ios::binary);
  if (!file) return {};
  const auto size = SDL_RWsize(&file);
  if (size <= 0) return {};
  auto bytes = std::make_unique<uint8_t[]>(size);
  const auto count = SDL_RWread(&file, bytes.get(), 1, static_cast<size_t>(size));
  return {std::move(bytes), count};
 }
 bool usePackage = false;
} SharedContent;
