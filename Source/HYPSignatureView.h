@import UIKit;
@import GLKit;

@interface HYPSignatureView : GLKView

@property (nonatomic) UIColor *strokeColor;
@property (nonatomic, readonly) BOOL hasSignature;

- (void)erase;
- (UIImage *)signatureImage;

@end
