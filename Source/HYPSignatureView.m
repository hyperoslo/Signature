#import "HYPSignatureView.h"

#import <OpenGLES/ES2/glext.h>

#define MAXIMUM_VERTECES 100000
#define QUADRATIC_DISTANCE_TOLERANCE 3.0 // Minimum distance to make a curve
#define STROKE_WIDTH_MAX 0.010
#define STROKE_WIDTH_MIN 0.002 // Stroke width determined by touch velocity
#define STROKE_WIDTH_SMOOTHING 0.5 // Low pass filter alpha
#define VELOCITY_CLAMP_MAX 5000
#define VELOCITY_CLAMP_MIN 20

static GLKVector3 StrokeColor = { 0, 0, 0 };
static float clearColor[4] = { 1, 1, 1, 0 };

// Vertex structure containing 3D point and color
struct HYPSignaturePoint {
    GLKVector3		vertex;
    GLKVector3		color;
};
typedef struct HYPSignaturePoint HYPSignaturePoint;


// Maximum verteces in signature
static const int maxLength = MAXIMUM_VERTECES;


// Append vertex to array buffer
static inline void addVertex(uint *length, HYPSignaturePoint v) {
    if ((*length) >= maxLength) {
        return;
    }

    GLvoid *data = glMapBufferOES(GL_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
    memcpy(data + sizeof(HYPSignaturePoint) * (*length), &v, sizeof(HYPSignaturePoint));
    glUnmapBufferOES(GL_ARRAY_BUFFER);

    (*length)++;
}

static inline CGPoint QuadraticPointInCurve(CGPoint start, CGPoint end, CGPoint controlPoint, float percent) {
    double a = pow((1.0 - percent), 2.0);
    double b = 2.0 * percent * (1.0 - percent);
    double c = pow(percent, 2.0);

    return (CGPoint) {
        a * start.x + b * controlPoint.x + c * end.x,
        a * start.y + b * controlPoint.y + c * end.y
    };
}

static float generateRandom(float from, float to) { return random() % 10000 / 10000.0 * (to - from) + from; }
static float clamp(float min, float max, float value) { return fmaxf(min, fminf(max, value)); }


// Find perpendicular vector from two other vectors to compute triangle strip around line
static GLKVector3 perpendicular(HYPSignaturePoint p1, HYPSignaturePoint p2) {
    GLKVector3 ret;
    ret.x = p2.vertex.y - p1.vertex.y;
    ret.y = -1 * (p2.vertex.x - p1.vertex.x);
    ret.z = 0;
    return ret;
}

static HYPSignaturePoint ViewPointToGL(CGPoint viewPoint, CGRect bounds, GLKVector3 color) {

    return (HYPSignaturePoint) {
        {
            (viewPoint.x / bounds.size.width * 2.0 - 1),
            ((viewPoint.y / bounds.size.height) * 2.0 - 1) * -1,
            0
        },
        color
    };
}


@interface HYPSignatureView () {
    // OpenGL state
    EAGLContext *context;
    GLKBaseEffect *effect;

    GLuint vertexArray;
    GLuint vertexBuffer;
    GLuint dotsArray;
    GLuint dotsBuffer;


    // Array of verteces, with current length
    HYPSignaturePoint SignatureVertexData[maxLength];
    uint length;

    HYPSignaturePoint SignatureDotsData[maxLength];
    uint dotsLength;


    // Width of line at current and previous vertex
    float penThickness;
    float previousThickness;


    // Previous points for quadratic bezier computations
    CGPoint previousPoint;
    CGPoint previousMidPoint;
    HYPSignaturePoint previousVertex;
    HYPSignaturePoint currentVelocity;
}

@property (nonatomic) BOOL hasSignature;

@end


@implementation HYPSignatureView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    [self initialize];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (!self) return nil;
    
    [self initialize];
    return self;
}

- (void)initialize {
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context) {
        [NSException raise:@"NSOpenGLES2ContextException" format:@"Failed to create OpenGL ES2 context"];
    }
    
    time(NULL);
    
    self.backgroundColor = [UIColor whiteColor];
    self.opaque = NO;
    
    self.context = context;
    self.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    self.enableSetNeedsDisplay = YES;
    
    // Turn on antialiasing
    self.drawableMultisample = GLKViewDrawableMultisample4X;
    
    [self setupGL];
    
    // Capture touches
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
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

- (void)dealloc {
    [self tearDownGL];

    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }

    context = nil;
}


- (void)drawRect:(CGRect)rect {
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


- (void)erase {
    length = 0;
    dotsLength = 0;
    self.hasSignature = NO;

    [self setNeedsDisplay];
}


- (UIImage *)signatureImage {
    return (self.hasSignature) ? [self snapshot] : nil;
}

#pragma mark - Gesture Recognizers

- (void)tap:(UITapGestureRecognizer *)tap {
    CGPoint l = [tap locationInView:self];

    if (tap.state == UIGestureRecognizerStateRecognized) {
        glBindBuffer(GL_ARRAY_BUFFER, dotsBuffer);

        HYPSignaturePoint touchPoint = ViewPointToGL(l, self.bounds, (GLKVector3){1, 1, 1});
        addVertex(&dotsLength, touchPoint);

        HYPSignaturePoint centerPoint = touchPoint;
        centerPoint.color = StrokeColor;
        addVertex(&dotsLength, centerPoint);

        static int segments = 20;
        GLKVector2 radius = (GLKVector2){
            clamp(0.00001, 0.02, penThickness * generateRandom(0.5, 1.5)),
            clamp(0.00001, 0.02, penThickness * generateRandom(0.5, 1.5))
        };
        GLKVector2 velocityRadius = radius;
        float angle = 0;

        for (int i = 0; i <= segments; i++) {

            HYPSignaturePoint p = centerPoint;
            p.vertex.x += velocityRadius.x * cosf(angle);
            p.vertex.y += velocityRadius.y * sinf(angle);

            addVertex(&dotsLength, p);
            addVertex(&dotsLength, centerPoint);

            angle += M_PI * 2.0 / segments;
        }

        addVertex(&dotsLength, touchPoint);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

    [self setNeedsDisplay];
}


- (void)longPress:(UILongPressGestureRecognizer *)longPress {
    [self erase];
}

- (void)pan:(UIPanGestureRecognizer *)pan {

    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);

    CGPoint velocity = [pan velocityInView:self];
    CGPoint location = [pan locationInView:self];

    currentVelocity = ViewPointToGL(velocity, self.bounds, (GLKVector3){0,0,0});
    float distance = 0.;
    if (previousPoint.x > 0) {
        distance = sqrtf((location.x - previousPoint.x) * (location.x - previousPoint.x) + (location.y - previousPoint.y) * (location.y - previousPoint.y));
    }

    float velocityMagnitude = sqrtf(velocity.x*velocity.x + velocity.y*velocity.y);
    float clampedVelocityMagnitude = clamp(VELOCITY_CLAMP_MIN, VELOCITY_CLAMP_MAX, velocityMagnitude);
    float normalizedVelocity = (clampedVelocityMagnitude - VELOCITY_CLAMP_MIN) / (VELOCITY_CLAMP_MAX - VELOCITY_CLAMP_MIN);

    float lowPassFilterAlpha = STROKE_WIDTH_SMOOTHING;
    float newThickness = (STROKE_WIDTH_MAX - STROKE_WIDTH_MIN) * (1 - normalizedVelocity) + STROKE_WIDTH_MIN;
    penThickness = penThickness * lowPassFilterAlpha + newThickness * (1 - lowPassFilterAlpha);

    if ([pan state] == UIGestureRecognizerStateBegan) {

        previousPoint = location;
        previousMidPoint = location;

        HYPSignaturePoint startPoint = ViewPointToGL(location, self.bounds, (GLKVector3){1, 1, 1});
        previousVertex = startPoint;
        previousThickness = penThickness;

        addVertex(&length, startPoint);
        addVertex(&length, previousVertex);

        self.hasSignature = YES;

    } else if ([pan state] == UIGestureRecognizerStateChanged) {

        CGPoint mid = CGPointMake((location.x + previousPoint.x) / 2.0, (location.y + previousPoint.y) / 2.0);

        if (distance > QUADRATIC_DISTANCE_TOLERANCE) {
            // Plot quadratic bezier instead of line
            unsigned int i;

            int segments = (int) distance / 1.5;

            float startPenThickness = previousThickness;
            float endPenThickness = penThickness;
            previousThickness = penThickness;

            for (i = 0; i < segments; i++)
            {
                penThickness = startPenThickness + ((endPenThickness - startPenThickness) / segments) * i;

                CGPoint quadPoint = QuadraticPointInCurve(previousMidPoint, mid, previousPoint, (float)i / (float)(segments));

                HYPSignaturePoint v = ViewPointToGL(quadPoint, self.bounds, StrokeColor);
                [self addTriangleStripPointsForPrevious:previousVertex next:v];

                previousVertex = v;
            }
        } else if (distance > 1.0) {

            HYPSignaturePoint v = ViewPointToGL(location, self.bounds, StrokeColor);
            [self addTriangleStripPointsForPrevious:previousVertex next:v];

            previousVertex = v;
            previousThickness = penThickness;
        }

        previousPoint = location;
        previousMidPoint = mid;

    } else if (pan.state == UIGestureRecognizerStateEnded | pan.state == UIGestureRecognizerStateCancelled) {

        HYPSignaturePoint v = ViewPointToGL(location, self.bounds, (GLKVector3){1, 1, 1});
        addVertex(&length, v);

        previousVertex = v;
        addVertex(&length, previousVertex);
    }

    [self setNeedsDisplay];
}


- (void)setStrokeColor:(UIColor *)strokeColor {
    _strokeColor = strokeColor;
    [self updateStrokeColor];
}


#pragma mark - Private

- (void)updateStrokeColor {
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0, white = 0.0;
    if (effect && self.strokeColor && [self.strokeColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        effect.constantColor = GLKVector4Make(red, green, blue, alpha);
    } else if (effect && self.strokeColor && [self.strokeColor getWhite:&white alpha:&alpha]) {
        effect.constantColor = GLKVector4Make(white, white, white, alpha);
    } else effect.constantColor = GLKVector4Make(0,0,0,1);
}


- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];

    CGFloat red, green, blue, alpha, white;
    if ([backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        clearColor[0] = red;
        clearColor[1] = green;
        clearColor[2] = blue;
    } else if ([backgroundColor getWhite:&white alpha:&alpha]) {
        clearColor[0] = white;
        clearColor[1] = white;
        clearColor[2] = white;
    }
}

- (void)bindShaderAttributes {
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(HYPSignaturePoint), 0);
}

- (void)setupGL {
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

- (void)addTriangleStripPointsForPrevious:(HYPSignaturePoint)previous next:(HYPSignaturePoint)next {
    float toTravel = penThickness / 2.0;

    for (int i = 0; i < 2; i++) {
        GLKVector3 p = perpendicular(previous, next);
        GLKVector3 p1 = next.vertex;
        GLKVector3 ref = GLKVector3Add(p1, p);

        float distance = GLKVector3Distance(p1, ref);
        float difX = p1.x - ref.x;
        float difY = p1.y - ref.y;
        float ratio = -1.0 * (toTravel / distance);

        difX = difX * ratio;
        difY = difY * ratio;

        HYPSignaturePoint stripPoint = {
            { p1.x + difX, p1.y + difY, 0.0 },
            StrokeColor
        };
        addVertex(&length, stripPoint);

        toTravel *= -1;
    }
}

- (void)tearDownGL {
    [EAGLContext setCurrentContext:context];

    glDeleteVertexArraysOES(1, &vertexArray);
    glDeleteBuffers(1, &vertexBuffer);

    glDeleteVertexArraysOES(1, &dotsArray);
    glDeleteBuffers(1, &dotsBuffer);

    effect = nil;
}

@end
