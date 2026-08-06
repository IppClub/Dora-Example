#include "Love/LovePhysicsFilter.h"
#include "playrho/d2/Body.hpp"
#include "playrho/d2/ChainShapeConf.hpp"
#include "playrho/d2/EdgeShapeConf.hpp"
#include "playrho/d2/Manifold.hpp"
#include "playrho/d2/Transformation.hpp"

#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <optional>
#include <vector>

namespace pr = playrho;
namespace pd = playrho::d2;
using namespace playrho;

namespace
{

std::uint64_t manifoldHash = UINT64_C(14695981039346656037);

void mixHash(std::int64_t value)
{
	for (unsigned shift = 0; shift < 64; shift += 8)
	{
		manifoldHash ^= static_cast<std::uint8_t>(static_cast<std::uint64_t>(value) >> shift);
		manifoldHash *= UINT64_C(1099511628211);
	}
}

void mixLength2(const pr::Length2& value)
{
	mixHash(std::llround(static_cast<double>(pr::Real{value[0] / pr::Meter}) * 100000.0));
	mixHash(std::llround(static_cast<double>(pr::Real{value[1] / pr::Meter}) * 100000.0));
}

void mixUnitVec(const pd::UnitVec& value)
{
	mixHash(std::llround(static_cast<double>(pd::GetX(value)) * 100000.0));
	mixHash(std::llround(static_cast<double>(pd::GetY(value)) * 100000.0));
}

void recordManifold(const pd::Manifold& manifold)
{
	mixHash(static_cast<std::int64_t>(manifold.GetType()));
	mixHash(manifold.GetPointCount());
	if (manifold.GetPointCount() == 0) return;
	mixLength2(manifold.GetLocalPoint());
	if (manifold.GetType() != pd::Manifold::e_circles)
		mixUnitVec(manifold.GetLocalNormal());
	for (auto i = pd::Manifold::size_type{0}; i < manifold.GetPointCount(); ++i)
	{
		mixLength2(manifold.GetPoint(i).localPoint);
		const auto feature = manifold.GetContactFeature(i);
		mixHash(feature.indexA);
		mixHash(feature.indexB);
		mixHash(static_cast<std::int64_t>(feature.typeA));
		mixHash(static_cast<std::int64_t>(feature.typeB));
	}
}

void require(bool condition, const char *message)
{
	if (!condition)
	{
		std::cerr << "FAIL: " << message << '\n';
		std::exit(1);
	}
}

pd::Transformation makePlayRhoTransform(float x, float y, float angle)
{
	return {pr::Length2{x * pr::Meter, y * pr::Meter},
		pd::UnitVec::Get(pr::Angle{angle * pr::Radian})};
}

struct GhostTopology
{
	std::optional<pr::Length2> previous;
	std::optional<pr::Length2> next;
};

void compareFlippedManifold(const pd::Manifold& direct,
	const pd::Manifold& flipped)
{
	require(flipped.GetPointCount() == direct.GetPointCount(),
		"flipped connected-edge manifold changed its point count");
	if (direct.GetPointCount() == 0)
	{
		return;
	}
	const auto expectedType = direct.GetType() == pd::Manifold::e_faceA
		? pd::Manifold::e_faceB
		: direct.GetType() == pd::Manifold::e_faceB
			? pd::Manifold::e_faceA
			: pd::Manifold::e_circles;
	require(flipped.GetType() == expectedType,
		"flipped connected-edge manifold has the wrong type");
	if (direct.GetType() == pd::Manifold::e_circles)
	{
		require(flipped.GetLocalPoint() == direct.GetPoint(0).localPoint
			&& flipped.GetPoint(0).localPoint == direct.GetLocalPoint(),
			"flipped connected edge-circle manifold did not exchange local points");
	}
	else
	{
		require(flipped.GetLocalNormal() == direct.GetLocalNormal()
			&& flipped.GetLocalPoint() == direct.GetLocalPoint(),
			"flipped connected edge-polygon reference face changed");
	}
	for (auto i = pd::Manifold::size_type{0}; i < direct.GetPointCount(); ++i)
	{
		if (direct.GetType() != pd::Manifold::e_circles)
		{
			require(flipped.GetPoint(i).localPoint == direct.GetPoint(i).localPoint,
				"flipped connected edge-polygon contact point changed");
		}
		require(flipped.GetContactFeature(i) == pr::Flip(direct.GetContactFeature(i)),
			"flipped connected-edge contact feature was not exchanged");
	}
}

void validateAndRecordManifold(const pd::Manifold& actual,
	const pd::Manifold& flipped)
{
	recordManifold(actual);
	compareFlippedManifold(actual, flipped);
}

pd::DistanceProxy makePlayRhoEdge(const GhostTopology& topology,
	const pr::Length2* vertices, const pd::UnitVec* normals)
{
	return {pr::NonNegative<pr::Length>{0.01_m}, 2, vertices, normals,
		topology.previous, topology.next};
}

void recordCircleManifold(const GhostTopology& topology,
	float x, float y, float radius)
{
	const pr::Length2 edgeVertices[]{{0_m, 0_m}, {1_m, 0_m}};
	const pd::UnitVec edgeNormals[]{pd::UnitVec::GetUp(), pd::UnitVec::GetDown()};
	const pr::Length2 circleVertex[]{{0_m, 0_m}};
	const auto edge = makePlayRhoEdge(topology, edgeVertices, edgeNormals);
	const auto circle = pd::DistanceProxy{pr::NonNegative<pr::Length>{radius * pr::Meter},
		1, circleVertex, nullptr};
	const auto edgeXf = makePlayRhoTransform(0.43f, -0.27f, 0.41f);
	const auto circleXf = pd::Mul(edgeXf, makePlayRhoTransform(x, y, 0.0f));
	const auto playRho = pd::CollideShapes(edge, edgeXf, circle, circleXf, {});
	const auto playRhoFlipped = pd::CollideShapes(circle, circleXf, edge, edgeXf, {});

	validateAndRecordManifold(playRho, playRhoFlipped);
}

void recordPolygonManifold(const GhostTopology& topology,
	float x, float y, float angle)
{
	const pr::Length2 edgeVertices[]{{0_m, 0_m}, {1_m, 0_m}};
	const pd::UnitVec edgeNormals[]{pd::UnitVec::GetUp(), pd::UnitVec::GetDown()};
	const pr::Length2 polygonVertices[]{{-0.2_m, -0.15_m}, {0.2_m, -0.15_m},
		{0.2_m, 0.15_m}, {-0.2_m, 0.15_m}};
	const pd::UnitVec polygonNormals[]{pd::UnitVec::GetDown(), pd::UnitVec::GetRight(),
		pd::UnitVec::GetUp(), pd::UnitVec::GetLeft()};
	const auto edge = makePlayRhoEdge(topology, edgeVertices, edgeNormals);
	const auto polygon = pd::DistanceProxy{pr::NonNegative<pr::Length>{0.01_m}, 4,
		polygonVertices, polygonNormals};
	const auto edgeXf = makePlayRhoTransform(0.43f, -0.27f, 0.41f);
	const auto polygonXf = pd::Mul(edgeXf, makePlayRhoTransform(x, y, angle));
	const auto playRho = pd::CollideShapes(edge, edgeXf, polygon, polygonXf, {});
	const auto playRhoFlipped = pd::CollideShapes(polygon, polygonXf, edge, edgeXf, {});

	validateAndRecordManifold(playRho, playRhoFlipped);
}

}

int main()
{
	static_assert(sizeof(pr::Filter::index_type) == 2);
	const auto positiveGroupA = pr::Filter{0u, 0u, 300};
	const auto positiveGroupB = pr::Filter{0u, 0u, 300};
	const auto negativeGroupA = pr::Filter{~0u, ~0u, -300};
	const auto negativeGroupB = pr::Filter{~0u, ~0u, -300};
	require(!pr::ShouldCollide(positiveGroupA, positiveGroupB),
		"PlayRho groupIndex unexpectedly overrode disabled masks");
	require(pr::ShouldCollide(negativeGroupA, negativeGroupB),
		"PlayRho groupIndex unexpectedly overrode enabled masks");
	require(!pr::ShouldCollide(positiveGroupA, pr::Filter{0u, 0u, 301}),
		"PlayRho category/mask filtering changed for different groups");
	require(Dora::Love::shouldPhysicsFiltersCollide(
		Dora::Love::PhysicsFilter{0u, 0u, 300}, Dora::Love::PhysicsFilter{0u, 0u, 300}),
		"Love positive group did not override disabled masks");
	require(!Dora::Love::shouldPhysicsFiltersCollide(
		Dora::Love::PhysicsFilter{0xffffu, 0xffffu, -300},
		Dora::Love::PhysicsFilter{0xffffu, 0xffffu, -300}),
		"Love negative group did not override enabled masks");
	require(!Dora::Love::shouldPhysicsFiltersCollide(
		Dora::Love::PhysicsFilter{0u, 0u, 300}, Dora::Love::PhysicsFilter{0u, 0u, 301}),
		"Love different groups did not fall back to category/mask filtering");

	const auto localCenter = pr::Length2{0.5_m, 0_m};
	auto body = pd::Body{pd::BodyConf{}.Use(pd::Sweep{
		pd::Position{pr::Length2{1.5_m, 1_m}, 0_deg}, localCenter})};
	pd::SetTransformation(body, pd::Transformation{
		pr::Length2{2_m, 3_m}, pd::UnitVec::GetRight()});
	require(pd::GetLocation(body) == pr::Length2{2_m, 3_m},
		"SetTransformation treated the body origin as the world center of mass");
	require(pd::GetWorldCenter(body) == pr::Length2{2.5_m, 3_m},
		"SetTransformation did not update the world center from the local center");
	pd::SetAngle(body, 90_deg);
	const auto rotatedLocation = pd::GetLocation(body);
	const auto rotatedCenter = pd::GetWorldCenter(body);
	require(std::abs(static_cast<double>(pr::Real{(rotatedLocation[0] - 2_m) / pr::Meter})) < 1e-6
		&& std::abs(static_cast<double>(pr::Real{(rotatedLocation[1] - 3_m) / pr::Meter})) < 1e-6,
		"SetAngle moved the body origin for a non-zero local center");
	require(std::abs(static_cast<double>(pr::Real{(rotatedCenter[0] - 2_m) / pr::Meter})) < 1e-6
		&& std::abs(static_cast<double>(pr::Real{(rotatedCenter[1] - 3.5_m) / pr::Meter})) < 1e-6,
		"SetAngle did not rotate the local center around the body origin");

	const pr::Length2 edgeVertices[]{{0_m, 0_m}, {1_m, 0_m}};
	const pd::UnitVec edgeNormals[]{pd::UnitVec::GetUp(), pd::UnitVec::GetDown()};
	const pr::Length2 circleVertex[]{pr::Length2{-0.05_m, 0.05_m}};
	const auto circle = pd::DistanceProxy{pr::NonNegative<pr::Length>{0.1_m}, 1,
		circleVertex, nullptr};
	const auto plainEdge = pd::DistanceProxy{pr::NonNegative<pr::Length>{0.01_m}, 2,
		edgeVertices, edgeNormals};
	const auto connectedEdge = pd::DistanceProxy{pr::NonNegative<pr::Length>{0.01_m}, 2,
		edgeVertices, edgeNormals, pr::Length2{-1_m, 1_m}, std::nullopt};
	const pr::Length2 nextCircleVertex[]{pr::Length2{1.05_m, 0.05_m}};
	const auto nextCircle = pd::DistanceProxy{pr::NonNegative<pr::Length>{0.1_m}, 1,
		nextCircleVertex, nullptr};
	const auto nextConnectedEdge = pd::DistanceProxy{pr::NonNegative<pr::Length>{0.01_m}, 2,
		edgeVertices, edgeNormals, std::nullopt, pr::Length2{2_m, 1_m}};

	require(pd::CollideShapes(plainEdge, pd::Transform_identity,
		circle, pd::Transform_identity, {}).GetPointCount() == 1,
		"plain edge did not generate the endpoint contact baseline");
	require(pd::CollideShapes(connectedEdge, pd::Transform_identity,
		circle, pd::Transform_identity, {}).GetPointCount() == 0,
		"previous ghost vertex did not transfer endpoint ownership");
	require(pd::CollideShapes(plainEdge, pd::Transform_identity,
		nextCircle, pd::Transform_identity, {}).GetPointCount() == 1,
		"plain edge did not generate the next-endpoint contact baseline");
	require(pd::CollideShapes(nextConnectedEdge, pd::Transform_identity,
		nextCircle, pd::Transform_identity, {}).GetPointCount() == 0,
		"next ghost vertex did not transfer endpoint ownership");

	auto edge = pd::EdgeShapeConf{pr::Length2{0_m, 0_m}, pr::Length2{1_m, 0_m}}
		.UsePreviousVertex(pr::Length2{-1_m, 1_m})
		.UseNextVertex(pr::Length2{2_m, 1_m});
	const auto edgeChild = pd::GetChild(edge, 0);
	require(edgeChild.GetPreviousVertex() ==
			std::optional<pr::Length2>{pr::Length2{-1_m, 1_m}}
		&& edgeChild.GetNextVertex() ==
			std::optional<pr::Length2>{pr::Length2{2_m, 1_m}},
		"EdgeShapeConf did not propagate connected-edge topology");

	auto chain = pd::ChainShapeConf{}.Set({
		pr::Length2{0_m, 0_m}, pr::Length2{1_m, 0_m}, pr::Length2{2_m, 1_m}})
		.UsePreviousVertex(pr::Length2{-1_m, 1_m})
		.UseNextVertex(pr::Length2{3_m, 1_m});
	const auto first = chain.GetChild(0);
	const auto last = chain.GetChild(1);
	require(first.GetPreviousVertex() == std::optional<pr::Length2>{pr::Length2{-1_m, 1_m}}
		&& first.GetNextVertex() == std::optional<pr::Length2>{pr::Length2{2_m, 1_m}},
		"open ChainShape did not expose first-child topology");
	require(last.GetPreviousVertex() == std::optional<pr::Length2>{pr::Length2{0_m, 0_m}}
		&& last.GetNextVertex() == std::optional<pr::Length2>{pr::Length2{3_m, 1_m}},
		"open ChainShape did not expose last-child topology");

	auto loop = pd::ChainShapeConf{}.Set({pr::Length2{0_m, 0_m},
		pr::Length2{1_m, 0_m}, pr::Length2{1_m, 1_m}, pr::Length2{0_m, 0_m}});
	require(loop.GetPreviousVertex() == std::optional<pr::Length2>{pr::Length2{1_m, 1_m}}
		&& loop.GetNextVertex() == std::optional<pr::Length2>{pr::Length2{1_m, 0_m}},
		"loop ChainShape did not initialize external topology");
	loop.ClearPreviousVertex().ClearNextVertex();
	require(!loop.GetChild(0).GetPreviousVertex()
		&& !loop.GetChild(loop.GetChildCount() - 1).GetNextVertex(),
		"clearing loop topology did not reach endpoint children");

	const std::vector<GhostTopology> topologies{
		{{pr::Length2{-1_m, 1_m}}, std::nullopt},
		{std::nullopt, {pr::Length2{2_m, 1_m}}},
		{{pr::Length2{-1_m, 1_m}}, {pr::Length2{2_m, 1_m}}},
		{{pr::Length2{-1_m, -1_m}}, {pr::Length2{2_m, -1_m}}},
		{{pr::Length2{-1_m, 1_m}}, {pr::Length2{2_m, -1_m}}},
		{{pr::Length2{-1_m, -1_m}}, {pr::Length2{2_m, 1_m}}},
	};
	for (const auto& topology : topologies)
	{
		// Offset the sampling grid from exact Voronoi and radius boundaries so
		// equivalent float algorithms are compared away from rounding ambiguity.
		for (auto x = -0.287f; x <= 1.3f; x += 0.097f)
		{
			for (auto y = -0.241f; y <= 0.25f; y += 0.047f)
			{
			recordCircleManifold(topology, x, y, 0.12f);
				for (const auto angle : {-0.6f, -0.3f, 0.0f, 0.3f, 0.6f})
				{
					recordPolygonManifold(topology, x, y, angle);
				}
			}
		}
	}

	constexpr auto expectedLoveBox2D11_5Hash = UINT64_C(0x95a865bab1a1aa84);
	require(manifoldHash == expectedLoveBox2D11_5Hash,
		"PlayRho connected-edge manifold matrix differs from the pinned Love 11.5 Box2D baseline");
	std::cout << "PASS: PlayRho body transform and pinned Love 11.5 connected-edge manifold baseline hash=0x"
		<< std::hex << manifoldHash << '\n';
	return 0;
}
