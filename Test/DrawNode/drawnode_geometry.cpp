bool runTests() {
	auto check = [](bool condition, const char* message) {
		if (!condition) throw std::runtime_error(message);
	};
	auto node = DrawNode::create();
	auto area = [&]() {
		double result = 0;
		const auto& vertices = node->getVertices();
		const auto& indices = node->getIndices();
		for (size_t i = 0; i < indices.size(); i += 3) {
			const auto& a = vertices[indices[i]].position;
			const auto& b = vertices[indices[i + 1]].position;
			const auto& c = vertices[indices[i + 2]].position;
			result += std::abs(Cross({a.x, a.y}, {b.x, b.y}, {c.x, c.y})) * 0.5;
		}
		return result;
	};
	auto noOverlap = [&](const char* message) {
		const auto& vertices = node->getVertices();
		const auto& indices = node->getIndices();
		for (float x = -22.37f; x < 122; x += 2.0f) {
			for (float y = -22.19f; y < 122; y += 2.0f) {
				int coverage = 0;
				for (size_t i = 0; i < indices.size(); i += 3) {
					auto point = [&](uint16_t index) { const auto& p = vertices[index].position; return Vec2{p.x, p.y}; };
					const Vec2 a = point(indices[i]), b = point(indices[i + 1]), c = point(indices[i + 2]);
					const float ab = Cross(a, b, {x, y}), bc = Cross(b, c, {x, y}), ca = Cross(c, a, {x, y});
					if ((ab > 1e-4 && bc > 1e-4 && ca > 1e-4) || (ab < -1e-4 && bc < -1e-4 && ca < -1e-4)) coverage++;
				}
				check(coverage <= 1, message);
			}
		}
	};
	const Color white(0xffffffff);
	const Color transparent(0);
	// Procedural contours must survive small sizes and large translations.
	node->drawRoundedRect(Rect{{0, 0}, {0.001f, 0.0006f}}, 0.0003f, white, 0, white);
	check(!node->getVertices().empty(), "Tiny rounded rectangles must not be removed by polygon epsilon");
	node->clear();
	node->drawRoundedRect(Rect{{0, 0}, {0.001f, 0.0006f}}, 0, white, 0, white);
	check(node->getVertices().size() == 4 && area() > 5e-7, "Zero-radius tiny rectangles must retain their fill");
	node->clear();
	node->drawSector({10000000, 10000000}, 100, 0, 270, white, 0, white);
	check(!node->getVertices().empty(), "Translated major sectors must not lose their fill to area cancellation");
	check(std::abs(area() - 7500 * std::acos(-1.0)) < 300, "Translated sectors must retain their wedge area");
	node->clear();
	node->drawSector({0, 0}, 0.001f, 0, 270, white, 0, white);
	check(area() > 2e-6, "Tiny sectors must retain the major wedge");
	node->clear();
	node->drawQuadraticBezier({0, 0}, {0.005f, 0.01f}, {0.01f, 0}, 0.001f, white);
	check(node->getVertices().size() > 8, "Tiny Bezier curves must retain their curvature");
	node->clear();
	node->drawSegment({0, 0}, {1e-6f, 0}, 1e-7f, white);
	check(node->getVertices().size() == 8, "Distinct tiny endpoints must retain a segment");
	node->clear();
	node->drawRing({0, 0}, 50, 60, transparent, 8, white);
	noOverlap("Overlapping inner and outer ring borders must blend only once");
	node->clear();
	node->drawRoundedRect(Rect{{0, 0}, {100, 30}}, 8, transparent, 20, white);
	noOverlap("Rounded rectangle borders wider than the inset must not fold or double blend");
	node->clear();
	for (float sweep : {30.f, 90.f, 270.f, 359.f}) {
		node->drawSector({0, 0}, 100, 0, sweep, transparent, 60, white);
		check(!node->getVertices().empty(), "Wide sector strokes must retain geometry");
		noOverlap("Wide or nearly full sector borders must blend only once");
		node->clear();
	}
	const std::vector<Vec2> rectangle = {{0, 0}, {100, 0}, {100, 100}, {0, 100}};
	node->drawPolygon(rectangle, white, 0, white);
	check(node->getVertices().size() == 4 && node->getIndices().size() == 6, "Convex fill must share four vertices");
	check(std::abs(area() - 10000) < 1e-3, "Convex fill must cover its polygon");
	node->clear();
	std::vector<Vec2> concave = {{0, 0}, {100, 0}, {100, 100}, {50, 50}, {0, 100}};
	for (int winding = 0; winding < 2; winding++) {
		node->drawPolygon(concave, white, 0, white);
		check(node->getVertices().size() == 5 && node->getIndices().size() == 9, "Concave triangulation must support both windings");
		check(std::abs(area() - 7500) < 1e-3, "Concave fill must not cover its notch");
		node->clear();
		std::reverse(concave.begin(), concave.end());
	}
	node->drawPolygon({{0, 0}, {100, 100}, {0, 100}, {100, 0}}, white, 0, white);
	check(node->getVertices().empty(), "Self-intersecting polygons must be rejected");
	// A pentagram has consistent turns, but must not use the convex fast path.
	std::vector<Vec2> star;
	for (int i = 0; i < 5; i++) {
		const float angle = i * 4.0f * std::acos(-1.0f) / 5.0f;
		star.push_back({std::cos(angle) * 100, std::sin(angle) * 100});
	}
	node->drawPolygon(star, white, 0, white);
	check(node->getVertices().empty(), "Star outlines must not be classified as convex");
	node->drawPolyline({{0, 0}, {100, 0}, {100, 100}}, 4, white, false);
	check(node->getVertices().size() == 14, "Polyline must share its join instead of repeating capsules");
	noOverlap("Ordinary polyline joins must not double blend");
	node->clear();
	node->drawPolyline({{0, 0}, {40, 100}, {45, 0}}, 12, white, false);
	check(node->getVertices().size() == 16, "Sharp corners must produce an actual bevel");
	noOverlap("Beveled sharp joins must not double blend");
	node->clear();
	node->drawPolyline(rectangle, 12, white, true);
	noOverlap("Closed polygon border joins must not double blend");
	node->clear();
	std::vector<Vec2> duplicateRectangle = {{0, 0}, {50, 0}, {100, 0}, {100, 100}, {0, 100}, {0, 0}};
	node->drawPolygon(duplicateRectangle, white, 0, white);
	check(node->getVertices().size() == 4, "Closing duplicates and collinear vertices must be cleaned");
	node->clear();
	node->drawPolyline({{0, 0}, {0, 0}}, 4, white, false);
	check(node->getVertices().size() == 4, "Coincident endpoints must draw a dot");
	node->clear();
	node->drawSegment({0, 0}, {100, 0}, 4, white);
	check(node->getVertices().size() == 8 && node->getIndices().size() == 18, "Single segments must share cap and body vertices");
	noOverlap("Segment caps must not overlap their body");
	node->clear();
	node->drawArc({0, 0}, 100, 0, 720, 4, white);
	const auto circleVertices = node->getVertices().size();
	const auto circleIndices = node->getIndices().size();
	node->clear();
	node->drawArc({0, 0}, 100, 0, 360, 4, white);
	check(node->getVertices().size() == circleVertices && node->getIndices().size() == circleIndices, "Sweeps over one revolution must clamp and close");
	node->clear();
	node->drawArc({0, 0}, 100, 0, -360, 4, white);
	check(node->getVertices().size() == circleVertices && node->getIndices().size() == circleIndices, "Negative full sweeps must close");
	node->clear();
	node->drawArc({0, 0}, 100, std::numeric_limits<float>::max(), -std::numeric_limits<float>::max(), 4, white);
	check(node->getVertices().size() == circleVertices, "Large finite angles must not overflow sweep calculation");
	node->clear();
	const float nan = std::numeric_limits<float>::quiet_NaN();
	node->drawArc({0, 0}, 0.01f, 0, 360, 0.001f, white);
	check(!node->getVertices().empty(), "Tiny full circles must retain at least three segments");
	node->clear();
	node->drawArc({0, 0}, 10, 0, 360, 20, white);
	check(node->getVertices().size() == 4, "A full stroke wider than its radius must become a filled disk");
	node->clear();
	const float inf = std::numeric_limits<float>::infinity();
	node->drawEllipse({nan, 0}, 4, 4, white);
	node->drawSegment({0, 0}, {100, 0}, inf, white);
	node->drawPolyline({{0, 0}, {nan, 0}}, 4, white, false);
	node->drawArc({0, 0}, 100, 0, inf, 4, white);
	node->drawPolygon(rectangle, white, nan, white);
	node->drawPolygon(rectangle, transparent, 0, white);
	check(node->getVertices().empty(), "Invalid or invisible commands must add no geometry");
	// New primitives: their area and topology, not just their vertex counts.
	Rect roundedRect{{0, 0}, {100, 60}};
	node->drawRoundedRect(roundedRect, 0, white, 0, white);
	check(node->getVertices().size() == 4 && std::abs(area() - 6000) < 1e-3, "Zero corner radius must draw a rectangle");
	node->clear();
	node->drawRoundedRect(roundedRect, 30, white, 0, white);
	const size_t roundedVertices = node->getVertices().size();
	const double roundedArea = area();
	check(std::abs(roundedArea - (6000 - 900 * (4 - std::acos(-1.0)))) < 50, "Rounded rectangles must retain curved corners");
	node->clear();
	node->drawRoundedRect(roundedRect, 1000, white, 0, white);
	check(node->getVertices().size() == roundedVertices && area() == roundedArea, "Oversized corner radii must clamp");
	node->clear();
	node->drawRing({0, 0}, 50, 100, white, 0, white);
	check(std::abs(area() - 7500 * std::acos(-1.0)) < 120, "Ring fill must preserve its hole");
	noOverlap("Ring triangles must not overlap");
	node->clear();
	node->drawRing({0, 0}, 0, 100, white, 0, white);
	check(std::abs(area() - 10000 * std::acos(-1.0)) < 150, "Zero inner radius must draw a disk");
	node->clear();
	node->drawSector({0, 0}, 100, 0, 270, white, 0, white);
	const double sectorArea = area();
	check(std::abs(sectorArea - 7500 * std::acos(-1.0)) < 150, "Major sectors must cover the major wedge");
	node->clear();
	node->drawSector({0, 0}, 100, 0, -270, white, 0, white);
	check(std::abs(area() - sectorArea) < 0.1, "Sector sweep must support both directions");
	node->clear();
	node->drawSector({0, 0}, 100, 0, 720, transparent, 4, white);
	for (const auto& vertex : node->getVertices()) check(std::hypot(vertex.position.x, vertex.position.y) > 90, "Full sector borders must omit radial edges");
	node->clear();
	node->drawSector({0, 0}, 100, 45, 45, white, 0, white);
	node->drawRing({0, 0}, 100, 50, white, 0, white);
	node->drawRoundedRect(roundedRect, -1, white, 0, white);
	node->drawQuadraticBezier({0, 0}, {nan, 0}, {100, 0}, 2, white);
	node->drawCubicBezier({0, 0}, {30, 0}, {60, inf}, {100, 0}, 2, white);
	check(node->getVertices().empty(), "Invalid new primitives must add no geometry");
	node->drawQuadraticBezier({0, 0}, {50, 0}, {100, 0}, 2, white);
	check(node->getVertices().size() == 8, "Straight Bezier strokes must reduce to a segment");
	node->clear();
	node->drawCubicBezier({0, 0}, {0, 0}, {0, 0}, {0, 0}, 2, white);
	check(node->getVertices().size() == 4, "Coincident Bezier controls must draw a dot");
	node->clear();
	std::vector<Vec2> curve = {{0, 0}};
	const std::array<Vec2, 3> controls = {{{0, 0}, {100, 200}, {200, 0}}};
	FlattenBezier(controls, curve);
	check(curve.size() > 2 && curve.size() <= 1025, "Curves must subdivide adaptively within the limit");
	for (int i = 0; i <= 100; i++) {
		const float t = i / 100.0f;
		const Vec2 point = controls[0] * ((1-t)*(1-t)) + controls[1] * (2*t*(1-t)) + controls[2] * (t*t);
		double distance = std::numeric_limits<double>::max();
		for (size_t j = 1; j < curve.size(); j++) distance = std::min(distance, DistanceToSegmentSquared(point, curve[j-1], curve[j]));
		check(distance <= 0.25 * 0.25, "Bezier subdivision must meet its target error");
	}
	curve = {{0, 0}};
	FlattenBezier(std::array<Vec2, 4>{{{0, 0}, {150, 0}, {-100, 0}, {20, 0}}}, curve);
	check(curve.size() > 2, "Collinear Bezier overshoots must not disappear");
	curve = {{0, 0}};
	const std::array<Vec2, 4> cubic = {{{0, 0}, {0, 200}, {200, -200}, {200, 0}}};
	FlattenBezier(cubic, curve);
	for (int i = 0; i <= 100; i++) {
		const float t = i / 100.0f, u = 1-t;
		const Vec2 point = cubic[0] * (u*u*u) + cubic[1] * (3*u*u*t) + cubic[2] * (3*u*t*t) + cubic[3] * (t*t*t);
		double distance = std::numeric_limits<double>::max();
		for (size_t j = 1; j < curve.size(); j++) distance = std::min(distance, DistanceToSegmentSquared(point, curve[j-1], curve[j]));
		check(distance <= 0.25 * 0.25, "Cubic subdivision must preserve its inflection within the target error");
	}
	curve = {{0, 0}};
	FlattenBezier(std::array<Vec2, 4>{{{0, 0}, {-100, 200}, {100, 200}, {0, 0}}}, curve);
	node->drawCubicBezier({0, 0}, {-100, 200}, {100, 200}, {0, 0}, 2, white);
	const size_t loopVertices = node->getVertices().size();
	node->clear();
	node->drawPolyline(curve, 2, white, true);
	check(node->getVertices().size() == loopVertices, "Coincident Bezier endpoints must share a closed join without caps");
	node->clear();
	std::vector<Vec2> oversized;
	for (int i = 0; i < 33000; i++) oversized.push_back({float(i * 10), float((i % 2) * 100)});
	node->drawPolyline(oversized, 1, white, false);
	check(node->getVertices().empty(), "Oversized stroke indices must never wrap");
	for (int i = 0; i < 16383; i++) node->drawDot({0, 0}, 1, white);
	const auto vertices = node->getVertices().size();
	const auto indices = node->getIndices().size();
	node->drawPolyline({{0, 0}, {100, 0}, {100, 100}}, 4, white, false);
	check(node->getVertices().size() == vertices && node->getIndices().size() == indices, "Capacity failure must reject the entire stroke");
	node->drawPolygon(rectangle, white, 4, white);
	check(node->getVertices().size() == vertices && node->getIndices().size() == indices, "Capacity failure must reject both fill and border");
	node->drawRoundedRect(roundedRect, 10, white, 4, white);
	node->drawRing({0, 0}, 20, 100, white, 4, white);
	node->drawSector({0, 0}, 100, 0, 270, white, 4, white);
	node->drawQuadraticBezier({0, 0}, {100, 200}, {200, 0}, 4, white);
	node->drawCubicBezier({0, 0}, {0, 200}, {200, -200}, {200, 0}, 4, white);
	check(node->getVertices().size() == vertices && node->getIndices().size() == indices, "All new commands must reject capacity failures atomically");
	return true;
}
