//
//  GRKSignatureViewTestAppTests.m
//  GRKSignatureViewTestAppTests
//
//  Created by Levi Brown on 9/29/17.
//  Copyright © 2017 Levi Brown. All rights reserved.
//

#import <XCTest/XCTest.h>

static const NSUInteger kNumTestIterations = 10000;
static const NSUInteger kMaxNumTestIterations = 1000000000;

static double generateRandomBetween(double a, double b) {
	u_int32_t random = arc4random_uniform(10001);
	double percent = random / (double)10000.0;
	double range = fabs(a - b);
	double value = percent * range;
	double shifted = value + (a < b ? a : b);
	return shifted;
}

@interface GRKSignatureViewTestAppTests : XCTestCase

@end

@implementation GRKSignatureViewTestAppTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testgenerateRandomBetween100 {
	float small = 0.0f;
	float big = 0.0f;
	
	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);

		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween200 {
	float small = 0.0f;
	float big = 1.0f;

	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(big, small); //NOTE reversed big/small
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween300 {
	float small = -1.0f;
	float big = 1.0f;
	
	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween400 {
	float small = -1.0f;
	float big = 10.0f;
	
	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween500 {
	float small = -0.0f;
	float big = 1.5f;
	
	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween600 {
	float small = -1.2f;
	float big = 1.5f;
	
	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween700 {
	float small = -1121.4f;
	float big = -1.5f;
	
	for (NSUInteger i = 0; i < kNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);
	}
}

- (void)testgenerateRandomBetween1000 {
	float small = -1.2f;
	float big = 1.8f;
	BOOL hitSmall = NO;
	BOOL hitBig = NO;
	
	for (NSUInteger i = 0; i < kMaxNumTestIterations; ++i) {
		double result = generateRandomBetween(small, big);
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);

		if (result == small) {
			hitSmall = YES;
		}
		else if (result == big) {
			hitBig = YES;
		}
		
		if (hitSmall && hitBig) {
			break;
		}
	}
	
	XCTAssertTrue(hitSmall, @"Did not hit \"small\" value (%.2f)", small);
	XCTAssertTrue(hitBig, @"Did not hit \"big\" value (%.2f)", big);
}

- (void)testRandImplementation {
	float small = -1.2f;
	float big = 1.8f;
	BOOL hitA = NO;
	BOOL hitB = NO;

	double a = small;
	double b = big;
	for (NSUInteger i = 0; i < kMaxNumTestIterations; ++i) {
		u_int32_t random = arc4random_uniform(10001);
		double percent = random / (double)10000.0;
		double range = fabs(a - b);
		double value = percent * range;
		double shifted = value + (a < b ? a : b);
		double result = shifted;
		XCTAssertGreaterThanOrEqual(result, small);
		XCTAssertLessThanOrEqual(result, big);

		if (result == a) {
			NSLog(@"Hit 'a':\n random: %u\n percent: %.3f\n range: %.3f\nvalue: %.3f\n shifted: %.3f\n result: %.3f", random, percent, range, value, shifted, result);
			hitA = YES;
		}
		else if (result == b) {
			NSLog(@"Hit 'b':\n random: %u\n percent: %.3f\n range: %.3f\nvalue: %.3f\n shifted: %.3f\n result: %.3f", random, percent, range, value, shifted, result);
			hitB = YES;
		}
		
		if (hitA && hitB) {
			break;
		}
	}
	
	XCTAssertTrue(hitA, @"Did not hit \"a\" value (%.2f)", a);
	XCTAssertTrue(hitB, @"Did not hit \"b\" value (%.2f)", b);
}

@end
