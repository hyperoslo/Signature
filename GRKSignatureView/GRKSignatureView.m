//
//  GRKSignatureView.m
//
//  Copyright (c) 2017 Levi Brown <mailto:levigroker@gmail.com> This work is
//  licensed under the Creative Commons Attribution 4.0 International License. To
//  view a copy of this license, visit https://creativecommons.org/licenses/by/4.0/
//
//  The above attribution and this license must accompany any version of the source
//  code, binary distributable, or derivatives.
//

#import "GRKSignatureView.h"
#import <OpenGLES/ES2/glext.h>
#import "GRKPanGestureRecognizer.h"

NSString * const GRKSignatureViewErrorDomain = @"GRKSignatureViewErrorDomain";

CGFloat const kGRKSignatureDefaultStrokeWidthMin = 0.002f;
CGFloat const kGRKSignatureDefaultStrokeWidthMax = 0.010f;

// Maximum verteces in signature
static const int maxLength = 100000;
// Minimum distance to make a curve
static const CGFloat kQuadradicDistanceTolerance = 3.0f;

// Stroke width smoothing
static const float kLowPassFilterAlpha = 0.5;

static const float kVelocityClampMax = 5000.0f;
static const float kVelocityClampMin = 20.0f;

static GLKVector3 StrokeColor = { 0, 0, 0 };
static float clearColor[4] = { 1, 1, 1, 0 };

// Vertex structure containing 3D point and color
struct GRKSignaturePoint {
	GLKVector3		vertex;
	GLKVector3		color;
};
typedef struct GRKSignaturePoint GRKSignaturePoint;

#pragma mark - Static Functions

static inline GLvoid *mapVertexBuffer(GLuint bufferToMap, NSError **error)
{
	glBindBuffer(GL_ARRAY_BUFFER, bufferToMap);
	
	GLvoid *data = glMapBufferOES(GL_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
	
	if (data == NULL && error != NULL) {
		GLenum glError = glGetError();
		NSDictionary *userInfo = @{@"GL_ERROR" : @(glError)};
		*error = [NSError errorWithDomain:GRKSignatureViewErrorDomain code:GRKSignatureViewErrorOpenGL userInfo:userInfo];
	}
	
	return data;
}

// Append vertex to array buffer
static inline void addVertex(GLvoid *mappedBuffer, uint *length, GRKSignaturePoint vertex)
{
	if ((*length) >= maxLength) {
		return;
	}
	
	memcpy(mappedBuffer + sizeof(GRKSignaturePoint) * (*length), &vertex, sizeof(GRKSignaturePoint));
	(*length)++;
}

static inline void unmapVertexBuffer(GLuint *mappedBuffer)
{
	if (mappedBuffer != NULL) {
		GLboolean result = glUnmapBufferOES(GL_ARRAY_BUFFER);
		
		if (result == GL_FALSE) {
			// GL docs say this indicates some kind of corruption, and the buffer should be reinitialized.
			// TODO: Reinitialize the buffer
		}
	}
	
	glBindBuffer(GL_ARRAY_BUFFER, 0);
}

static inline CGPoint QuadraticPointInCurve(CGPoint start, CGPoint end, CGPoint controlPoint, float percent)
{
	double a = pow((1.0 - percent), 2.0);
	double b = 2.0 * percent * (1.0 - percent);
	double c = pow(percent, 2.0);
	
	return (CGPoint) {
		a * start.x + b * controlPoint.x + c * end.x,
		a * start.y + b * controlPoint.y + c * end.y
	};
}

static double generateRandomBetween(double a, double b) {
	u_int32_t random = arc4random_uniform(10001);
	double percent = random / (double)10000.0;
	double range = fabs(a - b);
	double value = percent * range;
	double shifted = value + (a < b ? a : b);
	return shifted;
}

static float clamp(float min, float max, float value) { return fmaxf(min, fminf(max, value)); }


// Find perpendicular vector from two other vectors to compute triangle strip around line
static GLKVector3 perpendicular(GRKSignaturePoint p1, GRKSignaturePoint p2)
{
	GLKVector3 ret;
	ret.x = p2.vertex.y - p1.vertex.y;
	ret.y = -1 * (p2.vertex.x - p1.vertex.x);
	ret.z = 0;
	return ret;
}

static GRKSignaturePoint ViewPointToGL(CGPoint viewPoint, CGRect bounds, GLKVector3 color)
{
	return (GRKSignaturePoint) {
		{
			(viewPoint.x / bounds.size.width * 2.0 - 1),
			((viewPoint.y / bounds.size.height) * 2.0 - 1) * -1,
			0
		},
		color
	};
}


@interface GRKSignatureView ()
{
	// OpenGL state
	EAGLContext *context;
	GLKBaseEffect *effect;
	
	GLuint vertexArray;
	GLuint vertexBuffer;
	GLuint dotsArray;
	GLuint dotsBuffer;

	// Array of vertices, with current length
	GRKSignaturePoint SignatureVertexData[maxLength];
	uint length;
	
	GRKSignaturePoint SignatureDotsData[maxLength];
	uint dotsLength;

	// Width of line at current and previous vertex
	float penThickness;
	float previousThickness;

	// Previous points for quadratic bezier computations
	CGPoint previousPoint;
	CGPoint previousMidPoint;
	GRKSignaturePoint previousVertex;
}

@property (nonatomic, assign) BOOL hasSignature;

@end


@implementation GRKSignatureView

#pragma mark - Lifecycle

- (void)dealloc
{
	[self tearDownGL];
	
	if ([EAGLContext currentContext] == context) {
		[EAGLContext setCurrentContext:nil];
	}
	
	context = nil;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setup];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder])) {
		[self setup];
	}
	return self;
}

- (void)setup
{
	context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	if (!context) {
		[NSException raise:@"NSOpenGLES2ContextException" format:@"Failed to create OpenGL ES2 context"];
	}
	
	time(NULL);
	
	//Defaults
	self.backgroundColor = [UIColor clearColor];
	self.opaque = NO;
	
	self.context = context;
	self.drawableDepthFormat = GLKViewDrawableDepthFormat24;
	self.enableSetNeedsDisplay = YES;
	
	self.strokeWidthMin = kGRKSignatureDefaultStrokeWidthMin;
	self.strokeWidthMax = kGRKSignatureDefaultStrokeWidthMax;
	
	// Turn on antialiasing
	self.drawableMultisample = GLKViewDrawableMultisample4X;
	
	[self setupGL];
	
	// Capture touches
	GRKPanGestureRecognizer *pan = [[GRKPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
	pan.maximumNumberOfTouches = pan.minimumNumberOfTouches = 1;
	pan.cancelsTouchesInView = YES;
	[self addGestureRecognizer:pan];
	
	// For dotting your i's
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
	tap.cancelsTouchesInView = YES;
	[self addGestureRecognizer:tap];
	
	// Erase with long press
	UILongPressGestureRecognizer *longer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
	longer.cancelsTouchesInView = YES;
	[self addGestureRecognizer:longer];
}

#pragma mark - Overrides

- (void)drawRect:(CGRect)rect
{
	glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
	glClear(GL_COLOR_BUFFER_BIT);
	
	[effect prepareToDraw];
	
	// Drawing of signature lines
	if (length > 2) {
		glBindVertexArrayOES(vertexArray);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, length);
	}
	
	if (dotsLength > 0) {
		glBindVertexArrayOES(dotsArray);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, dotsLength);
	}
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
	[super setBackgroundColor:backgroundColor];
	
	CGFloat red, green, blue, alpha, white;
	if ([backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
		clearColor[0] = red;
		clearColor[1] = green;
		clearColor[2] = blue;
	}
	else if ([backgroundColor getWhite:&white alpha:&alpha]) {
		clearColor[0] = white;
		clearColor[1] = white;
		clearColor[2] = white;
	}
}

#pragma mark - Accessors

- (void)setStrokeWidthMin:(CGFloat)strokeWidthMin
{
	_strokeWidthMin = MAX(strokeWidthMin, 0.0f);
}

- (void)setStrokeWidthMax:(CGFloat)strokeWidthMax
{
	_strokeWidthMax = MAX(strokeWidthMax, 0.0f);
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
	_strokeColor = strokeColor;
	[self updateStrokeColor];
}

#pragma mark - Implementation

- (void)erase
{
	length = 0;
	dotsLength = 0;
	self.hasSignature = NO;
	
	[self setNeedsDisplay];
}

- (UIImage *)signatureImage
{
	return (self.hasSignature) ? [self snapshot] : nil;
}

#pragma mark - Actions

- (void)tap:(UITapGestureRecognizer *)tap
{
	if (tap.state == UIGestureRecognizerStateRecognized) {
		__autoreleasing NSError *error = nil;
		GLuint *mappedBuffer = mapVertexBuffer(dotsBuffer, &error);
		
		if (mappedBuffer == NULL) {
			// TODO: Handle the error condition
		}
		else {
			CGPoint l = [tap locationInView:self];
			GRKSignaturePoint touchPoint = ViewPointToGL(l, self.bounds, (GLKVector3){1, 1, 1});
			addVertex(mappedBuffer, &dotsLength, touchPoint);
			
			GRKSignaturePoint centerPoint = touchPoint;
			centerPoint.color = StrokeColor;
			addVertex(mappedBuffer, &dotsLength, centerPoint);
			
			static NSUInteger segments = 20;
			GLKVector2 radius = (GLKVector2) {
				clamp(0.00001f, 0.02f, penThickness * generateRandomBetween(0.5f, 1.5f)),
				clamp(0.00001f, 0.02f, penThickness * generateRandomBetween(0.5f, 1.5f))
			};
			GLKVector2 velocityRadius = radius;
			float angle = 0.0f;
			
			for (NSUInteger i = 0; i <= segments; ++i) {
				
				GRKSignaturePoint p = centerPoint;
				p.vertex.x += velocityRadius.x * cosf(angle);
				p.vertex.y += velocityRadius.y * sinf(angle);
				
				addVertex(mappedBuffer, &dotsLength, p);
				addVertex(mappedBuffer, &dotsLength, centerPoint);
				
				angle += M_PI * 2.0f / segments;
			}
			
			addVertex(mappedBuffer, &dotsLength, touchPoint);
		}
		
		unmapVertexBuffer(mappedBuffer);
	}
	
	[self setNeedsDisplay];
}

- (void)longPress:(UILongPressGestureRecognizer *)longPress
{
	if (self.eraseOnLongPress) {
		[self erase];
	}
}
- (void)pan:(GRKPanGestureRecognizer *)pan
{
	__autoreleasing NSError *error = nil;
	GLuint *mappedBuffer = mapVertexBuffer(vertexBuffer, &error);
	
	if (mappedBuffer == NULL) {
		// TODO: Handle the error condition
	}
	else {
		CGPoint velocity = [pan velocityInView:self];
		CGPoint location = [pan locationInView:self];
		
		float velocityMagnitude = sqrtf(velocity.x * velocity.x + velocity.y * velocity.y);
		float clampedVelocityMagnitude = clamp(kVelocityClampMin, kVelocityClampMax, velocityMagnitude);
		float normalizedVelocity = (clampedVelocityMagnitude - kVelocityClampMin) / (kVelocityClampMax - kVelocityClampMin);
		
		float newThickness = (self.strokeWidthMax - self.strokeWidthMin) * (1 - normalizedVelocity) + self.strokeWidthMin;
		penThickness = penThickness * kLowPassFilterAlpha + newThickness * (1 - kLowPassFilterAlpha);
		
		switch (pan.state) {
			case UIGestureRecognizerStatePossible: {
				// Do nothing
				break;
			}
			case UIGestureRecognizerStateBegan: {
				// Add the point where touches began
				CGPoint touchLocation = [pan touchPointInView:self];
				GRKSignaturePoint touchPoint = ViewPointToGL(touchLocation, self.bounds, (GLKVector3){1, 1, 1});
				previousVertex = touchPoint;
				addVertex(mappedBuffer, &length, touchPoint);
				addVertex(mappedBuffer, &length, previousVertex);

				previousPoint = location;
				previousMidPoint = location;
				previousThickness = penThickness;

				self.hasSignature = YES;
				
				// Fall through, and let the "began" point get added, with appropriate handling.
			}
			case UIGestureRecognizerStateChanged: {
				CGFloat distance = 0.0f;
				if (previousPoint.x > 0) {
					CGFloat xDelta = location.x - previousPoint.x;
					CGFloat yDelta = location.y - previousPoint.y;
					distance = sqrtf((xDelta * xDelta) + (yDelta * yDelta));
				}
				
				if (distance > 1.0f) {
					
					CGPoint mid = CGPointMake((location.x + previousPoint.x) / 2.0f, (location.y + previousPoint.y) / 2.0f);

					if (pan.state == UIGestureRecognizerStateBegan || distance > kQuadradicDistanceTolerance) {
						// Plot quadratic bezier instead of line
						
						CGFloat segments = distance / 1.5f;
						
						float startPenThickness = previousThickness;
						float endPenThickness = penThickness;
						previousThickness = penThickness;
						
						for (NSUInteger i = 0; i < segments; ++i) {
							penThickness = startPenThickness + ((endPenThickness - startPenThickness) / segments) * i;
							
							CGPoint quadPoint = QuadraticPointInCurve(previousMidPoint, mid, previousPoint, (CGFloat)i / segments);
							
							GRKSignaturePoint vertex = ViewPointToGL(quadPoint, self.bounds, StrokeColor);
							[self addTriangleStripPointsInMappedBuffer:mappedBuffer previous:previousVertex next:vertex];
							
							previousVertex = vertex;
						}
					}
					else {
						// The distance between points is small enough to not need a curve (or it is the inital touches), so
						// just plot a simple line
						GRKSignaturePoint vertex = ViewPointToGL(location, self.bounds, StrokeColor);
						[self addTriangleStripPointsInMappedBuffer:mappedBuffer previous:previousVertex next:vertex];
						
						previousVertex = vertex;
						previousThickness = penThickness;
					}
					previousPoint = location;
					previousMidPoint = mid;
				}
				break;
			}
			case UIGestureRecognizerStateEnded:
				// Fall through
			case UIGestureRecognizerStateCancelled: {
				GRKSignaturePoint vertex = ViewPointToGL(location, self.bounds, (GLKVector3){1, 1, 1});
				addVertex(mappedBuffer, &length, vertex);
				
				previousVertex = vertex;
				addVertex(mappedBuffer, &length, previousVertex);

				break;
			}
			case UIGestureRecognizerStateFailed: {
				// Do nothing
				break;
			}
			default: {
				// Do nothing
				break;
			}
		}
	}
	
	unmapVertexBuffer(mappedBuffer);
	
	[self setNeedsDisplay];
}


#pragma mark - Private

- (void)addTriangleStripPointsInMappedBuffer:(GLuint *)mappedBuffer previous:(GRKSignaturePoint)previous next:(GRKSignaturePoint)next
{
	float toTravel = penThickness / 2.0f;
	
	GLKVector3 p = perpendicular(previous, next);
	GLKVector3 p1 = next.vertex;
	GLKVector3 ref = GLKVector3Add(p1, p);
	
	float distance = GLKVector3Distance(p1, ref);
	float difX = p1.x - ref.x;
	float difY = p1.y - ref.y;

	for (NSUInteger i = 0; i < 2; ++i) {
		float ratio = -1.0f * (toTravel / distance);
		
		GRKSignaturePoint stripPoint = {
			{ p1.x + (difX * ratio), p1.y + (difY * ratio), 0.0f },
			StrokeColor
		};
		addVertex(mappedBuffer, &length, stripPoint);
		
		toTravel *= -1.0f;
	}
}

- (void)setupGL
{
	[EAGLContext setCurrentContext:context];
	
	effect = [[GLKBaseEffect alloc] init];
	
	[self updateStrokeColor];
	
	glDisable(GL_DEPTH_TEST);
	
	// Signature Lines
	glGenVertexArraysOES(1, &vertexArray);
	glBindVertexArrayOES(vertexArray);
	
	glGenBuffers(1, &vertexBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
	glBufferData(GL_ARRAY_BUFFER, sizeof(SignatureVertexData), SignatureVertexData, GL_DYNAMIC_DRAW);
	[self bindShaderAttributes];

	// Signature Dots
	glGenVertexArraysOES(1, &dotsArray);
	glBindVertexArrayOES(dotsArray);
	
	glGenBuffers(1, &dotsBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, dotsBuffer);
	glBufferData(GL_ARRAY_BUFFER, sizeof(SignatureDotsData), SignatureDotsData, GL_DYNAMIC_DRAW);
	[self bindShaderAttributes];
	
	glBindVertexArrayOES(0);
	
	// Perspective
	GLKMatrix4 ortho = GLKMatrix4MakeOrtho(-1, 1, -1, 1, 0.1f, 2.0f);
	effect.transform.projectionMatrix = ortho;
	
	GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.0f);
	effect.transform.modelviewMatrix = modelViewMatrix;
	
	length = 0;
	penThickness = 0.003;
	previousPoint = CGPointMake(-100, -100);
}

- (void)tearDownGL
{
	[EAGLContext setCurrentContext:context];
	
	glDeleteVertexArraysOES(1, &vertexArray);
	glDeleteBuffers(1, &vertexBuffer);
	
	glDeleteVertexArraysOES(1, &dotsArray);
	glDeleteBuffers(1, &dotsBuffer);
	
	effect = nil;
}

- (void)updateStrokeColor
{
	CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0, white = 0.0;
	if (effect && self.strokeColor && [self.strokeColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
		effect.constantColor = GLKVector4Make(red, green, blue, alpha);
	}
	else if (effect && self.strokeColor && [self.strokeColor getWhite:&white alpha:&alpha]) {
		effect.constantColor = GLKVector4Make(white, white, white, alpha);
	}
	else {
		effect.constantColor = GLKVector4Make(0,0,0,1);
	}
}

- (void)bindShaderAttributes
{
	glEnableVertexAttribArray(GLKVertexAttribPosition);
	glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GRKSignaturePoint), 0);
}

@end

