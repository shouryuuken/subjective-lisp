#import <QuartzCore/QuartzCore.h>

#define CP_ALLOW_PRIVATE_ACCESS
#import "ObjectiveChipmunk.h"

#import "CPViewController.h"

#import "CPDemo.h"
#import "PolyRenderer.h"

#define SLIDE_ANIMATION_DURATION 0.25
#define TITLE_ANIMATION_DURATION 0.25

#define MIN_TIMESCALE (1.0/64.0)
#define MAX_TIMESCALE 1.0

#define MIN_TIMESTEP (1.0/240.0)
#define MAX_TIMESTEP (1.0/30.0)

#define MAX_ITERATIONS 30

#define STAT_DELAY 1.0


@interface ChipmunkGLView : GLView

@property(nonatomic, assign) id touchesDelegate;

@end


@implementation ChipmunkGLView

@synthesize touchesDelegate = _touchesDelegate;

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
	[_touchesDelegate touchesBegan:touches withEvent:event];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	[_touchesDelegate touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
	[_touchesDelegate touchesEnded:touches withEvent:event];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[_touchesDelegate touchesCancelled:touches withEvent:event];
}

@end



@interface CPViewController(){
	CPDemo *_demo;
	PolyRenderer *_renderer;
	
    ChipmunkGLView *_glView;
	CADisplayLink *_displayLink;
	NSTimeInterval _lastTime, _lastFrameTime;

	int _renderTicks;
}

@property(nonatomic, retain) ChipmunkGLView *glView;

-(void)setupGL;

@end



@implementation CPViewController

@synthesize glView = _glView;

-(id)initWithDemoClassName:(NSString *)demo
{
	if((self = [super init])){
		_demo = [[NSClassFromString(demo) alloc] init];
	}
	
	return self;
}


//MARK: Load/Unload

-(void)setupGL
{
	[self.glView runInRenderQueue:^{
		GLfloat clear = 1.0;
		glClearColor(clear, clear, clear, 1.0);

		glEnable(GL_BLEND);
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		
		CGSize viewSize = self.glView.bounds.size;
		Transform proj = t_mult(t_scale((viewSize.height/viewSize.width)*(4.0/3.0), 1.0), t_ortho(cpBBNew(-320, -240, 320, 240)));
		_demo.touchTransform = t_mult(t_inverse(proj), t_ortho(cpBBNew(0, viewSize.height, viewSize.width, 0)));
		
		_renderer = [[PolyRenderer alloc] initWithProjection:proj];
	} sync:TRUE];
}

- (void)tearDownGL
{
	[self.glView runInRenderQueue:^{
		NSLog(@"Tearing down GL");
		_renderer = nil;
	} sync:TRUE];
}

-(void)loadView
{
    CGRect r = [[UIScreen mainScreen] bounds];
    self.view = self.glView = [[ChipmunkGLView alloc] initWithFrame:CGRectMake(0.0, 0.0, r.size.height, r.size.width)];
}
                   
-(void)viewDidLoad
{
	[super viewDidLoad];
	
	EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	NSAssert(context, @"Failed to create ES context");
	
//	_glViewController.preferredFramesPerSecond = 60.0;
//	[self.view addSubview:self.glView];
	self.glView.context = context;
	self.glView.touchesDelegate = _demo;
	
	// Add a nice shadow.
	self.glView.layer.shadowColor = [UIColor blackColor].CGColor;
	self.glView.layer.shadowOpacity = 1.0f;
	self.glView.layer.shadowOffset = CGSizeZero;
	self.glView.layer.shadowRadius = 15.0;
	self.glView.layer.masksToBounds = NO;
	self.glView.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.glView.bounds].CGPath;
	

	[self setupGL];
}

-(void)viewDidUnload
{    
	[super viewDidUnload];
	[self tearDownGL];
    self.glView = nil;
}

-(void)viewDidAppear:(BOOL)animated
{
	_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
	_displayLink.frameInterval = 1;
	[_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

-(void)viewDidDisappear:(BOOL)animated
{
	[_displayLink invalidate];
	_displayLink = nil;
}

-(void)dealloc
{
	[self tearDownGL];
    [super dealloc];
}

//MARK: Rotation

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation == UIInterfaceOrientationLandscapeRight;
}

#define MAX_DT (1.0/15.0)

-(void)tick:(CADisplayLink *)displayLink
{
	NSTimeInterval time = _displayLink.timestamp;
	
	NSTimeInterval dt = MIN(time - _lastTime, MAX_DT);
	[_demo update:dt];
	
	BOOL needs_sync = (time - _lastFrameTime > MAX_DT);
	if(!_glView.isRendering || needs_sync){
		if(needs_sync) [_glView sync];
		[_demo render:_renderer showContacts:NO];
		
		[_glView display:^{
			[_glView clear];
			[_renderer render];
		} sync:needs_sync];
		
		_renderTicks++;
		_lastFrameTime = time;
	}
	
	_lastTime = time;
}

-(void)reset;
{
	_demo = [[[_demo class] alloc] init];
		
	_renderTicks = 0;
	
	self.glView.touchesDelegate = _demo;
	
	[self setupGL];
}

@end
