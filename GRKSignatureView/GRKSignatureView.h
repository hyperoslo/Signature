//
//  GRKSignatureView.h
//
//  Copyright (c) 2017 Levi Brown <mailto:levigroker@gmail.com> This work is
//  licensed under the Creative Commons Attribution 4.0 International License. To
//  view a copy of this license, visit https://creativecommons.org/licenses/by/4.0/
//
//  The above attribution and this license must accompany any version of the source
//  code, binary distributable, or derivatives.
//

@import UIKit;
@import GLKit;

extern NSString * const GRKSignatureViewErrorDomain;

typedef NS_ENUM(NSUInteger, GRKSignatureViewError) {
	GRKSignatureViewErrorOpenGL = 1
};

/**
 * The default stroke width minimum.
 * @see strokeWidthMin
 */
extern CGFloat const kGRKSignatureDefaultStrokeWidthMin;
/**
 * The default stroke width maximum.
 * @see strokeWidthMax
 */
extern CGFloat const kGRKSignatureDefaultStrokeWidthMax;


@interface GRKSignatureView : GLKView

/**
 The color used to draw the stroke.
 */
@property (nonatomic, strong) UIColor *strokeColor;

/**
 The minimum stroke width (line thickness).
 The width is determined by touch velocity, so this is the minimum width for the dynamic range.
 */
@property (nonatomic, assign) CGFloat strokeWidthMin;

/**
 The maximum stroke width (line thickness).
 The width is determined by touch velocity, so this is the maximum width for the dynamic range.
 */
@property (nonatomic, assign) CGFloat strokeWidthMax;

/**
 Has the view captured any stroke?
 */
@property (nonatomic, readonly) BOOL hasSignature;

/**
 Should a long-press gesture erase the current stroke?
 */
@property (nonatomic, assign) BOOL eraseOnLongPress;

/**
 Erases the current stroke.
 */
- (void)erase;

/**
 Captures the current stroke as an image.

 @return A UIImage containing the contents of the view, with an alpha background.
 */
- (UIImage *)signatureImage;

@end

