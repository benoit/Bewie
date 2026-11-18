import CoreGraphics

struct PinAnchor {
    let id: Int
    /// The exact screen projection, including points beyond the visible map.
    let point: CGPoint
    let isOffscreen: Bool

    init(id: Int, point: CGPoint, isOffscreen: Bool = false) {
        self.id = id
        self.point = point
        self.isOffscreen = isOffscreen
    }
}

struct PlacedPin: Identifiable {
    let id: Int
    let anchor: CGPoint
    var center: CGPoint
    let isOffscreen: Bool

    init(id: Int, anchor: CGPoint, center: CGPoint, isOffscreen: Bool = false) {
        self.id = id
        self.anchor = anchor
        self.center = center
        self.isOffscreen = isOffscreen
    }
}

enum PinPlacement {
    static let stemHeight: CGFloat = 24
    private static let headHalfWidth: CGFloat = 24
    private static let selectedHalfWidth: CGFloat = 24
    private static let halfHeight: CGFloat = 24
    private static let gap: CGFloat = 3

    /// Keep every head touchable. The selected head has first priority; other
    /// heads yield without moving their exact geographic stem anchors.
    /// Offscreen heads remain on the perimeter, spreading along their closest
    /// edge before using an adjacent edge when that edge has no room left.
    static func resolve(_ anchors: [PinAnchor], in size: CGSize, selectedID: Int? = nil, exclusions: [CGRect] = []) -> [PlacedPin] {
        guard size.width > 0, size.height > 0 else { return [] }
        let ordered = anchors.sorted {
            if ($0.id == selectedID) != ($1.id == selectedID) { return $0.id == selectedID }
            let first = bearingOrder($0.point, in: size)
            let second = bearingOrder($1.point, in: size)
            if first != second { return first < second }
            if $0.point.x != $1.point.x { return $0.point.x < $1.point.x }
            if $0.point.y != $1.point.y { return $0.point.y < $1.point.y }
            return $0.id < $1.id
        }
        let distantLayout = anchors.filter(\.isOffscreen).allSatisfy {
            hypot($0.point.x-size.width/2, $0.point.y-size.height/2) > max(size.width,size.height)*4
        } && anchors.filter({ !$0.isOffscreen }).count <= 1
        var attemptedOrders: Set<[OrderingKey]> = []
        func result(_ order: [PinAnchor]) -> [PlacedPin]? {
            let key = order.map { OrderingKey(x: $0.point.x, y: $0.point.y,
                                             selected: $0.id == selectedID, offscreen: $0.isOffscreen) }
            guard attemptedOrders.insert(key).inserted else { return nil }
            var placed: [PlacedPin] = []
            for anchor in order {
                guard let center = candidateCenters(for: anchor, in: size, selectedID: selectedID,
                                                      placed: placed, anchors: anchors, exclusions: exclusions).first else { return nil }
                placed.append(makePin(anchor, center: center, in: size))
            }
            let byID = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0) })
            return anchors.compactMap { byID[$0.id] }
        }
        var best: [PlacedPin]?
        var bestWrongEdges = Int.max
        var bestCost = CGFloat.infinity
        func consider(_ pins: [PlacedPin]?) {
            guard let pins else { return }
            var wrongEdges = 0
            var cost: CGFloat = 0
            for pin in pins {
                guard let anchor = anchors.first(where: { $0.id == pin.id }) else { continue }
                let bounds = centerBounds(for: pin.id, in: size, selectedID: selectedID)
                let preferred = preferredCenter(for: anchor, in: bounds)
                if anchor.isOffscreen {
                    let validSide = (abs(pin.center.x-bounds.minX) < 0.1 && anchor.point.x < 0)
                        || (abs(pin.center.x-bounds.maxX) < 0.1 && anchor.point.x > size.width)
                        || (abs(pin.center.y-bounds.minY) < 0.1 && anchor.point.y < 0)
                        || (abs(pin.center.y-bounds.maxY) < 0.1 && anchor.point.y > size.height)
                    if !validSide { wrongEdges += 1 }
                    // Subtract the unattainable constant distance so very distant
                    // locations do not drown out the cost of displacing a circle.
                    cost += hypot(anchor.point.x-pin.center.x, anchor.point.y-pin.center.y)
                        - hypot(anchor.point.x-preferred.x, anchor.point.y-preferred.y)
                } else { cost += hypot(pin.center.x-preferred.x, pin.center.y-preferred.y) }
            }
            if wrongEdges < bestWrongEdges || (wrongEdges == bestWrongEdges && cost < bestCost) {
                best = pins
                bestWrongEdges = wrongEdges
                bestCost = cost
            }
        }
        let initial = result(ordered)
        if !distantLayout, let initial { return initial }
        consider(initial)
        if bestWrongEdges == 0, bestCost < 0.001, let best { return best }

        // Try both directions around the geographic ring, starting at each
        // remaining place. This bounded repair changes assignment order rather
        // than accepting a crossing or hiding it underneath another circle.
        let selected = ordered.filter { $0.id == selectedID }
        let others = ordered.filter { $0.id != selectedID }
        for reverse in [false, true] {
            let ring = reverse ? Array(others.reversed()) : others
            for start in ring.indices {
                let rotated = Array(ring[start...]) + Array(ring[..<start])
                let candidate = result(selected + rotated)
                if !distantLayout, let candidate { return candidate }
                consider(candidate)
            }
        }
        // Dense exact-location clusters can require moving the selected head
        // away from another stem. Its ordinary centered arrival remains the
        // first choice above; these attempts are only a geometric repair.
        if !selected.isEmpty {
            for reverse in [false, true] {
                let ring = reverse ? Array(others.reversed()) : others
                for start in ring.indices {
                    let rotated = Array(ring[start...]) + Array(ring[..<start])
                    let candidate = result(rotated + selected)
                    if !distantLayout, let candidate { return candidate }
                    consider(candidate)
                }
            }
        }
        if bestWrongEdges == 0, let best { return best }
        // A greedy choice can occupy the only legal slot needed by a later pin.
        // Backtrack over nearby candidates before allowing any geographic-side compromise.
        func correctSide(_ center: CGPoint, _ anchor: PinAnchor) -> Bool {
            guard anchor.isOffscreen else { return true }
            let b = centerBounds(for: anchor.id, in: size, selectedID: selectedID)
            return (abs(center.x-b.minX) < 0.1 && anchor.point.x < 0)
                || (abs(center.x-b.maxX) < 0.1 && anchor.point.x > size.width)
                || (abs(center.y-b.minY) < 0.1 && anchor.point.y < 0)
                || (abs(center.y-b.maxY) < 0.1 && anchor.point.y > size.height)
        }
        let forcedSides = anchors.filter(\.isOffscreen).map { anchor in
            [anchor.point.y < 0, anchor.point.x > size.width,
             anchor.point.y > size.height, anchor.point.x < 0]
        }
        let hasEdgeCapacity = (0..<4).allSatisfy { side in
            let forced = forcedSides.filter { $0[side] && $0.filter { $0 }.count == 1 }.count
            let length = side % 2 == 0 ? size.width : size.height
            let capacity = max(0, Int(max(0, length - 54) / 51) + 1)
            return forced <= capacity
        }
        let commonEdge = anchors.allSatisfy(\.isOffscreen) && (
            anchors.allSatisfy { $0.point.y < 0 } || anchors.allSatisfy { $0.point.x > size.width }
            || anchors.allSatisfy { $0.point.y > size.height } || anchors.allSatisfy { $0.point.x < 0 })
        if commonEdge && !hasEdgeCapacity {
            let xOrder = ordered.sorted { $0.point.x == $1.point.x ? $0.id < $1.id : $0.point.x < $1.point.x }
            let yOrder = ordered.sorted { $0.point.y == $1.point.y ? $0.id < $1.id : $0.point.y < $1.point.y }
            let bounds = centerBounds(for: -1, in: size, selectedID: nil)
            for horizontal in [false, true] {
                let available = horizontal ? bounds.width : bounds.height
                let needed = CGFloat(max(0, ordered.count-1))*51
                guard available >= needed else { continue }
                for edge in [horizontal ? bounds.minY : bounds.minX, horizontal ? bounds.maxY : bounds.maxX] {
                    let lower = horizontal ? bounds.minX : bounds.minY
                    for start in [lower, lower+(available-needed)/2, lower+available-needed] {
                        for order in [xOrder, Array(xOrder.reversed()), yOrder, Array(yOrder.reversed())] {
                            var placed: [PlacedPin] = []
                            for (index, anchor) in order.enumerated() {
                                let along = start+CGFloat(index)*51
                                let center = horizontal ? CGPoint(x:along,y:edge) : CGPoint(x:edge,y:along)
                                let pin = makePin(anchor, center:center, in:size)
                                let radius = circleRadius(for:anchor.id, selectedID:selectedID)
                                guard clearsExclusions(center,id:anchor.id,selectedID:selectedID,exclusions:exclusions),
                                      placed.allSatisfy({ other in
                                        !overlaps(center,id:anchor.id,with:other,selectedID:selectedID)
                                        && !segmentsCross(center,pin.anchor,other.center,other.anchor)
                                        && segmentDistanceSquared(from:center,to:pin.anchor,point:other.center) >= pow(circleRadius(for:other.id,selectedID:selectedID),2)
                                        && segmentDistanceSquared(from:other.center,to:other.anchor,point:center) >= radius*radius
                                      }) else { break }
                                placed.append(pin)
                            }
                            if placed.count == anchors.count {
                                let byID = Dictionary(uniqueKeysWithValues:placed.map { ($0.id,$0) })
                                consider(anchors.compactMap { byID[$0.id] })
                            }
                        }
                    }
                }
            }
            if let best { return best }
        }
        var searchOrders: [[PinAnchor]] = []
        if (hasEdgeCapacity && distantLayout) || commonEdge {
            for ring in [others, Array(others.reversed())] {
                for index in ring.indices {
                    searchOrders.append(selected + Array(ring[index...]) + Array(ring[..<index]))
                }
            }
        }
        if commonEdge {
            searchOrders += [ordered.sorted { $0.point.x == $1.point.x ? $0.point.y < $1.point.y : $0.point.x < $1.point.x },
                ordered.sorted { $0.point.y == $1.point.y ? $0.point.x < $1.point.x : $0.point.y < $1.point.y }]
        }
        let searchBudget = commonEdge ? 1_024 : 256
        var searchedOrders: Set<[OrderingKey]> = []
        for order in searchOrders {
            let key = order.map { OrderingKey(x:$0.point.x,y:$0.point.y,selected:$0.id == selectedID,offscreen:$0.isOffscreen) }
            guard searchedOrders.insert(key).inserted else { continue }
            var nodes = 0
            func search(_ placed: [PlacedPin]) -> [PlacedPin]? {
                nodes += 1
                guard nodes <= searchBudget else { return nil }
                guard placed.count < order.count else { return placed }
                let anchor = order[placed.count]
                var unique: [CGPoint] = []
                for point in candidateCenters(for: anchor, in: size, selectedID: selectedID,
                    placed: placed, anchors: anchors, exclusions: exclusions) where !hasEdgeCapacity || correctSide(point, anchor) {
                    if unique.allSatisfy({ squaredDistance($0, point) > 1 }) { unique.append(point) }
                    if unique.count == 10 { break }
                }
                for point in unique {
                    if let result = search(placed + [makePin(anchor, center: point, in: size)]) { return result }
                }
                return nil
            }
            if let solution = search([]) {
                let byID = Dictionary(uniqueKeysWithValues: solution.map { ($0.id, $0) })
                consider(anchors.compactMap { byID[$0.id] })
            }
        }
        if bestWrongEdges == 0, let best { return best }
        consider(perimeterFallback(ordered, originalOrder: anchors, in: size, selectedID: selectedID, exclusions: exclusions))
        return best ?? []
    }

    /// Resolve within an inset overlay while preserving exact map projections.
    static func resolve(_ anchors: [PinAnchor], in size: CGSize, selectedID: Int? = nil,
                        origin: CGPoint, exclusions: [CGRect] = []) -> [PlacedPin] {
        let local = anchors.map {
            PinAnchor(id: $0.id, point: CGPoint(x: $0.point.x - origin.x, y: $0.point.y - origin.y),
                      isOffscreen: $0.isOffscreen)
        }
        let localExclusions = exclusions.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
        return resolve(local, in: size, selectedID: selectedID, exclusions: localExclusions).map {
            PlacedPin(id: $0.id,
                      anchor: CGPoint(x: $0.anchor.x + origin.x, y: $0.anchor.y + origin.y),
                      center: CGPoint(x: $0.center.x + origin.x, y: $0.center.y + origin.y),
                      isOffscreen: $0.isOffscreen)
        }
    }

    private struct OrderingKey: Hashable {
        let x: CGFloat
        let y: CGFloat
        let selected: Bool
        let offscreen: Bool
    }

    private static func candidateCenters(for anchor: PinAnchor, in size: CGSize,
                                          selectedID: Int?, placed: [PlacedPin], anchors: [PinAnchor], exclusions: [CGRect]) -> [CGPoint] {
        let bounds = centerBounds(for: anchor.id, in: size, selectedID: selectedID)
        let preferred = preferredCenter(for: anchor, in: bounds)
        var xs = [bounds.minX, preferred.x, bounds.maxX]
        var ys = [bounds.minY, preferred.y, bounds.maxY]
        let ownHalfWidth = halfWidth(for: anchor.id, selectedID: selectedID)
        let radius = circleRadius(for: anchor.id, selectedID: selectedID) + 0.01
        for area in exclusions {
            xs += [area.minX - ownHalfWidth - gap - 0.01, area.maxX + ownHalfWidth + gap + 0.01]
                .map { clamp($0, bounds.minX, bounds.maxX) }
            ys += [area.minY - halfHeight - gap - 0.01, area.maxY + halfHeight + gap + 0.01]
                .map { clamp($0, bounds.minY, bounds.maxY) }
        }
        for other in anchors where other.id != anchor.id && !other.isOffscreen {
            xs.append(clamp(other.point.x - radius, bounds.minX, bounds.maxX))
            xs.append(clamp(other.point.x + radius, bounds.minX, bounds.maxX))
            ys.append(clamp(other.point.y - radius, bounds.minY, bounds.maxY))
            ys.append(clamp(other.point.y + radius, bounds.minY, bounds.maxY))
        }
        for other in placed {
            let horizontalDistance = ownHalfWidth + halfWidth(for: other.id, selectedID: selectedID) + gap
            xs.append(clamp(other.center.x - horizontalDistance, bounds.minX, bounds.maxX))
            xs.append(clamp(other.center.x + horizontalDistance, bounds.minX, bounds.maxX))
            ys.append(clamp(other.center.y - halfHeight * 2 - gap, bounds.minY, bounds.maxY))
            ys.append(clamp(other.center.y + halfHeight * 2 + gap, bounds.minY, bounds.maxY))
        }

        if anchor.isOffscreen {
            // Collision boundaries partition each edge into free intervals. The
            // nearest point in a free interval is either its endpoint or the
            // preferred projection, so these finite candidates are exhaustive.
            let edges: [[CGPoint]] = [
                edgeCandidates(horizontal: true, fixed: bounds.minY, values: xs, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds),
                edgeCandidates(horizontal: false, fixed: bounds.maxX, values: ys, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds),
                edgeCandidates(horizontal: true, fixed: bounds.maxY, values: xs, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds),
                edgeCandidates(horizontal: false, fixed: bounds.minX, values: ys, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds)
            ]
            // Compare all four edges together. Exhausting one preferred edge
            // first can send a pin hundreds of points away while an adjacent
            // edge has a much closer free position near the same corner.
            return freeCenters(edges.flatMap { $0 }, to: anchor.point, id: anchor.id,
                               selectedID: selectedID, placed: placed, anchor: anchor,
                               anchors: anchors, size: size, exclusions: exclusions)
        }

        // Axis-aligned hit areas partition the viewport into rectangles. Their
        // boundary coordinates also contain the nearest available interior point.
        let candidates = ys.flatMap { y in
            edgeCandidates(horizontal: true, fixed: y, values: xs, anchor: anchor, placed: placed,
                           selectedID: selectedID, bounds: bounds)
        }
        return freeCenters(candidates, to: preferred, id: anchor.id, selectedID: selectedID, placed: placed, anchor: anchor, anchors: anchors, size: size, exclusions: exclusions)
    }


    /// Rectangle boundaries alone do not describe stem clearance. Add the
    /// circle tangencies and stem-capsule intersections along each candidate row.
    private static func edgeCandidates(horizontal: Bool, fixed: CGFloat, values: [CGFloat],
                                       anchor: PinAnchor, placed: [PlacedPin], selectedID: Int?, bounds: CGRect) -> [CGPoint] {
        var coordinates = values
        func add(_ value: CGFloat) {
            guard value.isFinite else { return }
            coordinates.append(value - 0.01)
            coordinates.append(value + 0.01)
        }
        func axes(_ point: CGPoint) -> (CGFloat, CGFloat) {
            horizontal ? (point.x, point.y) : (point.y, point.x)
        }
        let (anchorAlong, anchorAcross) = axes(anchor.point)
        for other in placed {
            let (circleAlong, circleAcross) = axes(other.center)
            // Tangent rays from the true endpoint delimit where a new straight
            // stem can pass either side of this existing circle.
            let dx = circleAlong - anchorAlong
            let dy = circleAcross - anchorAcross
            let length = hypot(dx, dy)
            let radius = circleRadius(for: other.id, selectedID: selectedID)
            if length > radius {
                let along = sqrt(length * length - radius * radius) / length
                let across = radius / length
                for sign: CGFloat in [-1, 1] {
                    let tangentAlong = dx / length * along - sign * dy / length * across
                    let tangentAcross = dy / length * along + sign * dx / length * across
                    if abs(tangentAcross) > 0.0000001 {
                        let distance = (fixed - anchorAcross) / tangentAcross
                        if distance > 0 { add(anchorAlong + tangentAlong * distance) }
                    }
                }
            }

            // A new circle also has to clear each existing stem. Its forbidden
            // interval is the intersection with that segment's round capsule.
            let ownRadius = circleRadius(for: anchor.id, selectedID: selectedID)
            let (endAlong, endAcross) = axes(other.anchor)
            for endpoint in [(circleAlong, circleAcross), (endAlong, endAcross)] {
                let offset = fixed - endpoint.1
                if abs(offset) <= ownRadius {
                    let delta = sqrt(max(0, ownRadius * ownRadius - offset * offset))
                    add(endpoint.0 - delta)
                    add(endpoint.0 + delta)
                }
            }
            let stemAlong = endAlong - circleAlong
            let stemAcross = endAcross - circleAcross
            let stemLength = hypot(stemAlong, stemAcross)
            if abs(stemAcross) > 0.0000001 {
                for sign: CGFloat in [-1, 1] {
                    add(circleAlong + ((fixed - circleAcross) * stemAlong + sign * ownRadius * stemLength) / stemAcross)
                }
            }
        }
        let lower = horizontal ? bounds.minX : bounds.minY
        let upper = horizontal ? bounds.maxX : bounds.maxY
        return coordinates.map { coordinate in
            let value = clamp(coordinate, lower, upper)
            return horizontal ? CGPoint(x: value, y: fixed) : CGPoint(x: fixed, y: value)
        }
    }

    private static func freeCenters(_ candidates: [CGPoint], to preferred: CGPoint, id: Int,
                                    selectedID: Int?, placed: [PlacedPin], anchor: PinAnchor, anchors: [PinAnchor], size: CGSize, exclusions: [CGRect]) -> [CGPoint] {
        candidates.filter { point in
            let pin = makePin(anchor, center: point, in: size)
            let radius = circleRadius(for: id, selectedID: selectedID)
            return clearsExclusions(point, id: id, selectedID: selectedID, exclusions: exclusions)
                && anchors.allSatisfy { $0.id == id || $0.isOffscreen || squaredDistance($0.point, point) >= radius * radius }
                && placed.allSatisfy { other in
                    !overlaps(point, id: id, with: other, selectedID: selectedID)
                        && !segmentsCross(point, pin.anchor, other.center, other.anchor)
                        && segmentDistanceSquared(from: point, to: pin.anchor, point: other.center)
                        >= pow(circleRadius(for: other.id, selectedID: selectedID), 2)
                        && segmentDistanceSquared(from: other.center, to: other.anchor, point: point) >= radius * radius
                }
        }.sorted {
            let firstDistance = squaredDistance($0, preferred)
            let secondDistance = squaredDistance($1, preferred)
            if firstDistance != secondDistance { return firstDistance < secondDistance }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.x < $1.x
        }
    }

    private static func clearsExclusions(_ center: CGPoint, id: Int, selectedID: Int?, exclusions: [CGRect]) -> Bool {
        let halfWidth = halfWidth(for: id, selectedID: selectedID)
        let target = CGRect(x: center.x - halfWidth, y: center.y - halfHeight,
                            width: halfWidth * 2, height: halfHeight * 2).insetBy(dx: -gap, dy: -gap)
        return exclusions.allSatisfy { !target.intersects($0) }
    }

    private static func overlaps(_ center: CGPoint, id: Int, with other: PlacedPin, selectedID: Int?) -> Bool {
        // A tiny tolerance avoids rejecting candidates exactly on a boundary
        // through floating-point rounding; the visible targets still have a gap.
        abs(center.x - other.center.x) < halfWidth(for: id, selectedID: selectedID)
            + halfWidth(for: other.id, selectedID: selectedID) + gap - 0.001
            && abs(center.y - other.center.y) < halfHeight * 2 + gap - 0.001
    }

    private static func perimeterFallback(_ ordered: [PinAnchor], originalOrder: [PinAnchor],
                                          in size: CGSize, selectedID: Int?, exclusions: [CGRect]) -> [PlacedPin] {
        // Sample the perimeter more densely as a final bounded repair, always
        // preferring the true location rather than the opposite corner.
        for attempt in 0..<8 {
            let cornerOffset = attempt % 4
            var placed: [PlacedPin] = []
            let rotated = Array(ordered.dropFirst(cornerOffset)) + Array(ordered.prefix(cornerOffset))
            for anchor in attempt < 4 ? rotated : ordered {
                let bounds = centerBounds(for: anchor.id, in: size, selectedID: selectedID)
                var preferred = preferredCenter(for: anchor, in: bounds)
                if attempt >= 4 {
                    // Only a dense cluster with no nearby straight-stem layout
                    // reaches this final fan-out repair. Ordinary map views have
                    // already returned a geographically correct nearest layout.
                    let corners = [CGPoint(x:bounds.minX,y:bounds.minY), CGPoint(x:bounds.maxX,y:bounds.minY),
                        CGPoint(x:bounds.maxX,y:bounds.maxY), CGPoint(x:bounds.minX,y:bounds.maxY)]
                    let farthest = corners.indices.max { squaredDistance(corners[$0],anchor.point) < squaredDistance(corners[$1],anchor.point) } ?? 0
                    preferred = corners[(farthest+cornerOffset) % 4]
                }
                let xSteps = max(1, Int(bounds.width / 12))
                let ySteps = max(1, Int(bounds.height / 12))
                let xs = (0...xSteps).map { bounds.minX + bounds.width * CGFloat($0) / CGFloat(xSteps) }
                let ys = (0...ySteps).map { bounds.minY + bounds.height * CGFloat($0) / CGFloat(ySteps) }
                let candidates = [
                    edgeCandidates(horizontal: true, fixed: bounds.minY, values: xs, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds),
                    edgeCandidates(horizontal: false, fixed: bounds.maxX, values: ys, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds),
                    edgeCandidates(horizontal: true, fixed: bounds.maxY, values: xs, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds),
                    edgeCandidates(horizontal: false, fixed: bounds.minX, values: ys, anchor: anchor, placed: placed, selectedID: selectedID, bounds: bounds)
                ].flatMap { $0 }
                guard let center = freeCenters(candidates, to: preferred, id: anchor.id,
                                               selectedID: selectedID, placed: placed, anchor: anchor,
                                               anchors: ordered, size: size, exclusions: exclusions).first else { break }
                placed.append(makePin(anchor, center: center, in: size))
            }
            if placed.count == ordered.count {
                let byID = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0) })
                return originalOrder.compactMap { byID[$0.id] }
            }
        }
        // Defensive capacity fallback: preserve distinct, reachable circles
        // even if an unvalidated geometry exhausts all straight-stem repairs.
        // Never collapse the heads back onto their crowded preferred positions.
        let bounds = centerBounds(for: -1, in: size, selectedID: nil)
        let xSteps = max(1, Int(bounds.width / (headHalfWidth * 2 + gap)))
        let ySteps = max(1, Int(bounds.height / (halfHeight * 2 + gap)))
        let xs = (0...xSteps).map { bounds.minX + bounds.width * CGFloat($0) / CGFloat(xSteps) }
        let ys = (0...ySteps).map { bounds.minY + bounds.height * CGFloat($0) / CGFloat(ySteps) }
        var slots = xs.flatMap { [CGPoint(x: $0, y: bounds.minY), CGPoint(x: $0, y: bounds.maxY)] }
        slots += ys.dropFirst().dropLast().flatMap { [CGPoint(x: bounds.minX, y: $0), CGPoint(x: bounds.maxX, y: $0)] }
        var placed: [PlacedPin] = []
        for anchor in ordered {
            let preferred = preferredCenter(for: anchor, in: centerBounds(for: anchor.id, in: size, selectedID: selectedID))
            let ownBounds = centerBounds(for: anchor.id, in: size, selectedID: selectedID)
            let candidates = exclusions.isEmpty ? (anchor.id == selectedID ? [preferred] : slots) : ([preferred] + slots).map {
                CGPoint(x: clamp($0.x, ownBounds.minX, ownBounds.maxX), y: clamp($0.y, ownBounds.minY, ownBounds.maxY))
            }
            let center = candidates.filter { point in
                clearsExclusions(point, id: anchor.id, selectedID: selectedID, exclusions: exclusions)
                    && placed.allSatisfy { !overlaps(point, id: anchor.id, with: $0, selectedID: selectedID) }
            }.min { squaredDistance($0, preferred) < squaredDistance($1, preferred) } ?? preferred
            placed.append(makePin(anchor, center: center, in: size))
        }
        let byID = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0) })
        return originalOrder.compactMap { byID[$0.id] }
    }

    private static func preferredCenter(for anchor: PinAnchor, in bounds: CGRect) -> CGPoint {
        let point = anchor.point.x.isFinite && anchor.point.y.isFinite ? anchor.point
            : CGPoint(x: bounds.midX, y: bounds.midY)
        return CGPoint(x: clamp(point.x, bounds.minX, bounds.maxX),
                       y: clamp(point.y - (anchor.isOffscreen ? 0 : stemHeight), bounds.minY, bounds.maxY))
    }

    private static func centerBounds(for id: Int, in size: CGSize, selectedID: Int?) -> CGRect {
        let xInset = min(halfWidth(for: id, selectedID: selectedID) + gap, size.width / 2)
        let yInset = min(halfHeight + gap, size.height / 2)
        return CGRect(x: xInset, y: yInset, width: max(0, size.width - 2 * xInset),
                      height: max(0, size.height - 2 * yInset))
    }

    private static func makePin(_ anchor: PinAnchor, center: CGPoint, in size: CGSize) -> PlacedPin {
        let endpoint = anchor.isOffscreen ? clippedRay(from: center, toward: anchor.point, in: size) : anchor.point
        return PlacedPin(id: anchor.id, anchor: endpoint, center: center, isOffscreen: anchor.isOffscreen)
    }

    /// A displaced edge head still points toward the real offscreen location.
    private static func clippedRay(from center: CGPoint, toward point: CGPoint, in size: CGSize) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return center }
        let tx = dx > 0 ? (size.width - center.x) / dx : dx < 0 ? -center.x / dx : CGFloat.infinity
        let ty = dy > 0 ? (size.height - center.y) / dy : dy < 0 ? -center.y / dy : CGFloat.infinity
        let t = min(tx, ty)
        return CGPoint(x: clamp(center.x + dx * t, 0, size.width),
                       y: clamp(center.y + dy * t, 0, size.height))
    }

    private static func halfWidth(for id: Int, selectedID: Int?) -> CGFloat {
        id == selectedID ? selectedHalfWidth : headHalfWidth
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }


    private static func circleRadius(for id: Int, selectedID: Int?) -> CGFloat { id == selectedID ? 23 : 18 }

    private static func bearingOrder(_ point: CGPoint, in size: CGSize) -> CGFloat {
        let angle = atan2(point.y - size.height / 2, point.x - size.width / 2) + .pi / 2
        return angle < 0 ? angle + .pi * 2 : angle
    }

    private static func segmentsCross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func orientation(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat {
            (q.x-p.x)*(r.y-p.y) - (q.y-p.y)*(r.x-p.x)
        }
        let first = orientation(a,b,c), second = orientation(a,b,d)
        let third = orientation(c,d,a), fourth = orientation(c,d,b)
        return ((first > 0.0001 && second < -0.0001) || (first < -0.0001 && second > 0.0001))
            && ((third > 0.0001 && fourth < -0.0001) || (third < -0.0001 && fourth > 0.0001))
    }

    private static func segmentDistanceSquared(from start: CGPoint, to end: CGPoint, point: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return squaredDistance(start, point) }
        let t = clamp(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared, 0, 1)
        return squaredDistance(CGPoint(x: start.x + t * dx, y: start.y + t * dy), point)
    }

    private static func squaredDistance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return dx * dx + dy * dy
    }
}
