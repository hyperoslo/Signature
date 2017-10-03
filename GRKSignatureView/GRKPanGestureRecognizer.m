//
//  GRKPanGestureRecognizer.m
//
//  Created by Levi Brown on 2017/10/2
//  Copyright (c) 2017 Levi Brown <mailto:levigroker@gmail.com> This work is
//  licensed under the Creative Commons Attribution 4.0 International License. To
//  view a copy of this license, visit https://creativecommons.org/licenses/by/4.0/
//
//  The above attribution and this license must accompany any version of the source
//  code, binary distributable, or derivatives.
//
//  See https://stackoverflow.com/a/22119222/397210
//

#import "GRKPanGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

const CGFloat kDistanceToRecognizeDefault = 2.0f;
const CGFloat kDistanceToRecognizeMin = 1.0f;

@interface GRKPanGestureRecognizer ()

@property (assign,nonatomic) CGPoint touchPoint;

@end

@implementation GRKPanGestureRecognizer

#pragma mark - Lifecycle

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action])) {
		_touchPoint = CGPointMake(-1.0f, -1.0f);
		_distanceToRecognize = kDistanceToRecognizeDefault;
	}
	
	return self;
}

#pragma mark - Overrides

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	UITouch *touch = [touches anyObject];
	
	// touchPoint is defined as: @property (assign,nonatomic) CGPoint touchPoint;
	
	self.touchPoint = [touch locationInView:nil];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	UITouch *touch = [touches anyObject];
	CGPoint p = [touch locationInView:nil];
	
	// customize the pan distance threshold
	
	CGFloat dx = fabs(p.x - self.touchPoint.x);
	CGFloat dy = fabs(p.y - self.touchPoint.y);
	
	if ( dx > 2 || dy > 2) {
		if (self.state == UIGestureRecognizerStatePossible) {
			self.state = UIGestureRecognizerStateBegan;
		}
		else {
			self.state = UIGestureRecognizerStateChanged;
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	
	if (self.state == UIGestureRecognizerStateChanged) {
		self.state = UIGestureRecognizerStateEnded;
	}
	else {
		self.state = UIGestureRecognizerStateCancelled;
	}
}

- (void)reset
{
	[super reset];
	self.touchPoint = CGPointMake(-1.0f, -1.0f);
}

#pragma mark - Accessors

- (void)setDistanceToRecognize:(CGFloat)distanceToRecognize
{
	_distanceToRecognize = MAX(kDistanceToRecognizeMin, distanceToRecognize);
}

#pragma mark - Implementation

- (CGPoint)touchPointInView:(UIView *)view
{
	CGPoint retVal = [view convertPoint:self.touchPoint fromView:nil];
	return retVal;
}

@end
