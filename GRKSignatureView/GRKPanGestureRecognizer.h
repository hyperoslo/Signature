//
//  GRKPanGestureRecognizer.h
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

#import <UIKit/UIKit.h>

extern const CGFloat kDistanceToRecognizeDefault;
extern const CGFloat kDistanceToRecognizeMin;

@interface GRKPanGestureRecognizer : UIPanGestureRecognizer

/**
 The distance (in points) the recognizer will wait to recognize a "pan" gesture.
 The minimum value is `kDistanceToRecognizeMin`.
 */
@property (nonatomic, assign) CGFloat distanceToRecognize;

/**
 Get the initial touch point of the gesture which is recognized in the coordinates of a given view.

 @param view The view whose coordinate system to use.
 @return A CGPoint with the initial touch point.
 */
- (CGPoint)touchPointInView:(UIView *)view;

@end
