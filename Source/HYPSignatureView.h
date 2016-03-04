@import UIKit;
@import GLKit;

/**
 * The default stroke width minimum.
 * @see strokeWidthMin
 */
extern CGFloat const kHYPSignatureDefaultStrokeWidthMin;
/**
 * The default stroke width maximum.
 * @see strokeWidthMax
 */
extern CGFloat const kHYPSignatureDefaultStrokeWidthMax;


@interface HYPSignatureView : GLKView

@property (nonatomic) UIColor *strokeColor;
/**
 * The minimum stroke width (line thickness).
 * The width is determined by touch velocity, so this is the minimum width for the dynamic range.
 */
@property (nonatomic, assign) CGFloat strokeWidthMin;
/**
 * The maximum stroke width (line thickness).
 * The width is determined by touch velocity, so this is the maximum width for the dynamic range.
 */
@property (nonatomic, assign) CGFloat strokeWidthMax;

@property (nonatomic, readonly) BOOL hasSignature;

- (void)erase;
- (UIImage *)signatureImage;

@end
