// The MIT License (MIT)
//
// Copyright (c) 2015-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Nuke

extension ImageCache {
    subscript(request: ImageRequest) -> Image? {
        get {
            return cachedResponse(for: request)?.image
        }
        set {
            if let newValue = newValue {
                storeResponse(ImageResponse(image: newValue, urlResponse: nil), for: request)
            } else {
                removeResponse(for: request)
            }
        }
    }
}

private func _request(index: Int) -> ImageRequest {
    return ImageRequest(url: URL(string: "http://example.com/img\(index)")!)
}
private let request1 = _request(index: 1)
private let request2 = _request(index: 2)
private let request3 = _request(index: 3)

class ImageCacheTests: XCTestCase {
    var cache: ImageCache!

    override func setUp() {
        super.setUp()

        cache = ImageCache()
    }

    // MARK: Count

    func testThatTotalCountChanges() {
        XCTAssertEqual(cache.totalCount, 0)
        cache[request1] = defaultImage
        XCTAssertEqual(cache.totalCount, 1)
        cache[request2] = defaultImage
        XCTAssertEqual(cache.totalCount, 2)
        cache[request2] = nil
        XCTAssertEqual(cache.totalCount, 1)
        cache[request1] = nil
        XCTAssertEqual(cache.totalCount, 0)
    }

    func testThatItemsAreRemoveImmediatelyWhenCountLimitIsReached() {
        cache.countLimit = 1

        cache[request1] = defaultImage
        XCTAssertNotNil(cache[request1])

        cache[request2] = defaultImage
        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
    }

    func testTrimToCount() {
        cache[request1] = defaultImage
        cache[request2] = defaultImage

        XCTAssertNotNil(cache[request1])
        XCTAssertNotNil(cache[request2])

        cache.trim(toCount: 1)

        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
    }

    func testThatImagesAreRemovedOnCountLimitChange() {
        cache.countLimit = 2

        cache[request1] = defaultImage
        cache[request2] = defaultImage

        XCTAssertNotNil(cache[request1])
        XCTAssertNotNil(cache[request2])

        cache.countLimit = 1

        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
    }

    // MARK: Cost

    #if !os(macOS)

    func testDefaultImageCost() {
        XCTAssertEqual(cache.cost(defaultImage), 1228800)
    }

    func testThatTotalCostChanges() {
        let imageCost = cache.cost(defaultImage)

        XCTAssertEqual(cache.totalCost, 0)
        cache[request1] = defaultImage
        XCTAssertEqual(cache.totalCost, imageCost)
        cache[request2] = defaultImage
        XCTAssertEqual(cache.totalCost, 2 * imageCost)
        cache[request2] = nil
        XCTAssertEqual(cache.totalCost, imageCost)
        cache[request1] = nil
        XCTAssertEqual(cache.totalCost, 0)
    }

    func testThatItemsAreRemoveImmediatelyWhenCostLimitIsReached() {
        let cost = cache.cost(defaultImage)
        cache.costLimit = Int(Double(cost) * 1.5)

        cache[request1] = defaultImage
        XCTAssertNotNil(cache[request1])

        // LRU item is released
        cache[request2] = defaultImage
        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
    }

    func testTrimToCost() {
        cache.costLimit = Int.max

        cache[request1] = defaultImage
        cache[request2] = defaultImage

        XCTAssertNotNil(cache[request1])
        XCTAssertNotNil(cache[request2])

        let cost = cache.cost(defaultImage)
        cache.trim(toCost: Int(Double(cost) * 1.5))

        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
    }

    func testThatImagesAreRemovedOnCostLimitChange() {
        let cost = cache.cost(defaultImage)
        cache.costLimit = Int(Double(cost) * 2.5)

        cache[request1] = defaultImage
        cache[request2] = defaultImage

        XCTAssertNotNil(cache[request1])
        XCTAssertNotNil(cache[request2])

        cache.costLimit = cost

        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
    }

    #endif

    func testThatAfterAddingEntryForExistingKeyCostIsUpdated() {
        cache.cost = { _ in 10 }

        cache[request1] = defaultImage
        cache[request2] = defaultImage

        XCTAssertEqual(cache.totalCost, 20)

        cache.cost = { _ in 5 }

        cache[request1] = defaultImage
        XCTAssertEqual(cache.totalCost, 15)
    }

    // MARK: LRU

    func testThatLeastRecentItemsAreRemoved() {
        let cost = cache.cost(defaultImage)
        cache.costLimit = Int(Double(cost) * 2.5)

        // case 1
        cache[request1] = defaultImage
        cache[request2] = defaultImage
        cache[request3] = defaultImage
        XCTAssertNil(cache[request1])
        XCTAssertNotNil(cache[request2])
        XCTAssertNotNil(cache[request3])
    }

    func testThatItemsAreTouched() {
        let cost = cache.cost(defaultImage)
        cache.costLimit = Int(Double(cost) * 2.5)

        // case 2
        cache[request1] = defaultImage
        cache[request2] = defaultImage

        // touched image
        let _ = cache[request1]

        cache[request3] = defaultImage

        XCTAssertNotNil(cache[request1])
        XCTAssertNil(cache[request2])
        XCTAssertNotNil(cache[request3])
    }

    // MARK: Misc

    func testRemoveAll() {
        cache[request1] = defaultImage
        cache[request2] = defaultImage
        XCTAssertEqual(cache.totalCount, 2)
        cache.removeAll()
        XCTAssertEqual(cache.totalCount, 0)
        XCTAssertEqual(cache.totalCost, 0)
    }

    #if os(iOS) || os(tvOS)
    func testThatImagesAreRemovedOnMemoryWarnings() {
        let request = ImageRequest(url: defaultURL)
        cache[request] = Image()
        XCTAssertNotNil(cache[request])

        NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)

        XCTAssertNil(cache[request])
    }

    func testThatSomeImagesAreRemovedOnDidEnterBackground() {
        cache.costLimit = Int.max
        cache.countLimit = 10 // 1 out of 10 images should remain

        for i in 0..<10 {
            cache[_request(index: i)] = defaultImage
        }

        XCTAssertEqual(cache.totalCount, 10)

        NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)

        XCTAssertEqual(cache.totalCount, 1)
    }

    func testThatSomeImagesAreRemovedBasedOnCostOnDidEnterBackground() {

        let cost = cache.cost(defaultImage)
        cache.costLimit = cost * 10
        cache.countLimit = Int.max

        for i in 0..<10 {
            let request = ImageRequest(url: URL(string: "http://example.com/img\(i)")!)
            cache[request] = defaultImage
        }

        XCTAssertEqual(cache.totalCount, 10)

        NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)

        XCTAssertEqual(cache.totalCount, 1)
    }
    #endif

    // MARK: Thread Safety

    func testThreadSafety() {
        let cache = ImageCache()

        func rnd_cost() -> Int {
            return (2 + rnd(20)) * 1024 * 1024
        }

        var ops = [() -> Void]()

        for _ in 0..<10 { // those ops happen more frequently
            ops += [
                { cache[_request(index: rnd(10))] = defaultImage },
                { cache[_request(index: rnd(10))] = nil },
                { let _ = cache[_request(index: rnd(10))] }
            ]
        }

        ops += [
            { cache.costLimit = rnd_cost() },
            { cache.countLimit = rnd(10) },
            { cache.trim(toCost: rnd_cost()) },
            { cache.removeAll() }
        ]

        #if os(iOS) || os(tvOS)
        ops.append {
            NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
        }
        ops.append {
            NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        }
        #endif

        for _ in 0..<5000 {
            expect { fulfill in
                DispatchQueue.global().async {
                    ops.randomItem()()
                    fulfill()
                }
            }
        }

        wait()
    }
}

class ImageCacheIntegrationTests: XCTestCase {
    var mockCache: MockImageCache!
    var mockDataLoader: MockDataLoader!
    var pipeline: ImagePipeline!
    var target: ImageView!

    override func setUp() {
        super.setUp()

        mockCache = MockImageCache()
        mockDataLoader = MockDataLoader()
        pipeline = ImagePipeline {
            $0.dataLoader = mockDataLoader
            $0.imageCache = mockCache
        }
        target = ImageView()
    }

    func testThatCacheWorks() {
        let request = ImageRequest(url: defaultURL)

        XCTAssertEqual(mockCache.images.count, 0)
        XCTAssertNil(mockCache.cachedResponse(for: request))

        expect { fulfill in
            Nuke.loadImage(
                with: request,
                options: ImageLoadingOptions(
                    pipeline: pipeline,
                    completion: { response, _, _ in
                        XCTAssertNotNil(response)
                        fulfill()
                }),
                into: target
            )
        }
        wait()

        // Suspend queue to make sure that the next request can
        // come only from cache.
        mockDataLoader.queue.isSuspended = true

        expect { fulfill in
            Nuke.loadImage(
                with: request,
                options: ImageLoadingOptions(
                    pipeline: pipeline,
                    completion: { response, _, _ in
                        XCTAssertNotNil(response)
                        fulfill()
                }),
                into: target
            )
        }
        wait()

        XCTAssertEqual(mockCache.images.count, 1)
        XCTAssertNotNil(mockCache.cachedResponse(for: request))
    }

    func testThatStoreResponseMethodWorks() {
        let request = ImageRequest(url: defaultURL)
        
        XCTAssertEqual(mockCache.images.count, 0)
        XCTAssertNil(mockCache.cachedResponse(for: request))

        mockCache.storeResponse(Test.response, for: request)
        
        XCTAssertEqual(mockCache.images.count, 1)
        let image = mockCache.cachedResponse(for: request)
        XCTAssertNotNil(image)
    }

    func testThatCacheStorageCanBeDisabled() {
        var request = ImageRequest(url: defaultURL)
        XCTAssertTrue(request.memoryCacheOptions.writeAllowed)
        request.memoryCacheOptions.writeAllowed = false // Test default value

        XCTAssertEqual(mockCache.images.count, 0)
        XCTAssertNil(mockCache.cachedResponse(for: request))

        expect { fulfill in
            Nuke.loadImage(
                with: request,
                options: ImageLoadingOptions(
                    pipeline: pipeline,
                    completion: { response, _, _ in
                        XCTAssertNotNil(response)
                        fulfill()
                }),
                into: target
            )
        }
        wait()

        XCTAssertEqual(mockCache.images.count, 0)
        XCTAssertNil(mockCache.cachedResponse(for: request))
    }
}

class _CacheTTLTests: XCTestCase {
    let cache = _Cache<Int, Int>(costLimit: 1000, countLimit: 1000)

    // MARK: TTL

    func testTTL() {
        cache.set(1, forKey: 1, cost: 1, ttl: 0.05)  // 50 ms
        XCTAssertNotNil(cache.value(forKey: 1))

        usleep(55 * 1000)
        XCTAssertNil(cache.value(forKey: 1))
    }

    func testDefaultTTLIsUsed() {
        cache.ttl = 0.05// 50 ms
        cache.set(1, forKey: 1, cost: 1)
        XCTAssertNotNil(cache.value(forKey: 1))

        usleep(55 * 1000)
        XCTAssertNil(cache.value(forKey: 1))
    }

    func testDefaultToNonExpiringEntries() {
        cache.set(1, forKey: 1, cost: 1)
        XCTAssertNotNil(cache.value(forKey: 1))

        usleep(55 * 1000)
        XCTAssertNotNil(cache.value(forKey: 1))
    }
}
