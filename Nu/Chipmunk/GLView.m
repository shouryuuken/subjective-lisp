//
//  GLView.m
//  ChipmunkShowcase
//
//  Created by Scott Lembcke on 2/18/12.
//  Copyright (c) 2012 Howling Moon Software. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "GLView.h"
#import "PolyRenderer.h"

#import <objc/runtime.h>

#import "Nu.h"

#define GRABABLE_MASK_BIT (1<<31)
#define NOT_GRABABLE_MASK (~GRABABLE_MASK_BIT)




@implementation GLView {
	GLuint _framebuffer;
	GLuint _renderbuffer;
	
	BOOL _isRendering;
	dispatch_queue_t _renderQueue;

	PolyRenderer *_renderer;
	NSTimeInterval _lastFrameTime;
	
	// Convert touches to absolute coords.
	Transform _touchTransform;
	
	NSTimeInterval _accumulator;
	NSTimeInterval _fixedTime;
    
    ChipmunkSpace *_space;
}

@synthesize isRendering = _isRendering;
@synthesize context = _context;
@synthesize drawableWidth = _drawableWidth, drawableHeight = _drawableHeight;
@synthesize displayLink = _displayLink;
@synthesize touchTransform = _touchTransform;

@synthesize ticks = _ticks;
@synthesize fixedTime = _fixedTime;
@synthesize accumulator = _accumulator;
@synthesize timeScale = _timeScale;

@synthesize timeStep = _timeStep;

-(void)setupGL
{
	[self runInRenderQueue:^{
		GLfloat clear = 1.0;
		glClearColor(clear, clear, clear, 1.0);
        
		glEnable(GL_BLEND);
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		
		CGSize viewSize = self.bounds.size;
		Transform proj = t_mult(t_scale((viewSize.height/viewSize.width)*(4.0/3.0), 1.0), t_ortho(cpBBNew(-320, -240, 320, 240)));
		self.touchTransform = t_mult(t_inverse(proj), t_ortho(cpBBNew(0, viewSize.height, viewSize.width, 0)));
		
		_renderer = [[PolyRenderer alloc] initWithProjection:proj];
	} sync:TRUE];
}

- (void)tearDownGL
{
	[self runInRenderQueue:^{
		NSLog(@"Tearing down GL");
		_renderer = nil;
	} sync:TRUE];
}


-(void)sync
{
    if (!_renderQueue)
        return;
	dispatch_sync(_renderQueue, ^{});
}

-(void)runInRenderQueue:(void (^)(void))block sync:(BOOL)sync;
{
    if (!_renderQueue)
        return;
	(sync ? dispatch_sync : dispatch_async)(_renderQueue, ^{
		[EAGLContext setCurrentContext:_context];
		
		block();
		
		GLenum err = 0;
		for(err = glGetError(); err; err = glGetError()) NSLog(@"GLError: 0x%04X", err);
		NSAssert(err == GL_NO_ERROR, @"Aborting due to GL Errors.");
		
		[EAGLContext setCurrentContext:nil];
	});
}

//MARK: Framebuffer

- (BOOL)createFramebuffer
{
	glGenFramebuffers(1, &_framebuffer);
	glGenRenderbuffers(1, &_renderbuffer);
	
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
	
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_drawableWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_drawableHeight);
	
	NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Framebuffer creation failed 0x%x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
	NSLog(@"New framebuffer: %dx%d", _drawableWidth, _drawableHeight);
	
	glViewport(0, 0, _drawableWidth, _drawableHeight);
	
	return YES;
}

- (void)destroyFramebuffer
{
	glDeleteFramebuffers(1, &_framebuffer);
	_framebuffer = 0;
	
	glDeleteRenderbuffers(1, &_renderbuffer);
	_renderbuffer = 0;
}

-(void)clear
{
	const GLenum discards[]  = {GL_COLOR_ATTACHMENT0};
	glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, discards);
	
	glClearColor(52.0/255.0, 62.0/255.0, 72.0/255.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
}

- (void)layoutSubviews
{
	[self runInRenderQueue:^{
		[self destroyFramebuffer];
		[self createFramebuffer];
		[self clear];
	} sync:TRUE];
}

-(void)setContext:(EAGLContext *)context
{
	[self runInRenderQueue:^{
		_context = context;
		NSAssert(_context && [EAGLContext setCurrentContext:_context] && [self createFramebuffer], @"Failed to set up context.");
	} sync:TRUE];
}

//MARK: Memory methods

+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)r
{
	if((self = [super initWithFrame:r])) {

		
		_timeScale = 1.0;
		_timeStep = 1.0 / 60.0;

		
        CAEAGLLayer *layer = (CAEAGLLayer*) self.layer;
		
		layer.opaque = YES;
		layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
			kEAGLColorFormatRGB565, kEAGLDrawablePropertyColorFormat,
			nil
		];
		
		layer.contentsScale = [UIScreen mainScreen].scale;

		_renderQueue = dispatch_queue_create("net.chipmunk-physics.showcase-renderqueue", NULL);
		
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        NSAssert(_context, @"Failed to create ES context");
        
        [self setupGL];
        
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(tick:)]];
        [invocation setTarget:self];
        [invocation setSelector:@selector(tick:)];
        self.displayLink = [CADisplayLink displayLinkWithTarget:invocation selector:@selector(invoke)];
        self.displayLink.frameInterval = 1;
        objc_setAssociatedObject(self.displayLink, @"ios6sucks", invocation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    }
	
	return self;
}

-(void)dealloc
{
    NSLog(@"GLView dealloc %p", self);
	[self.displayLink invalidate];
	self.displayLink = nil;

    [self tearDownGL];
    
	[self runInRenderQueue:^{
		[self destroyFramebuffer];
	} sync:TRUE];
	
	dispatch_release(_renderQueue);
    
    [super dealloc];
}

//MARK: Render methods

-(void)display:(void (^)(void))block sync:(BOOL)sync;
{
	// Only queue one frame to render at a time unless synced.
	if(sync || !_isRendering){
		_isRendering = TRUE;
		
		[self runInRenderQueue:^{
			glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
			
			block();
			
			glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
			[_context presentRenderbuffer:GL_RENDERBUFFER];
						
			_isRendering = FALSE;
		} sync:sync];
	}
}

#define MAX_DT (1.0/15.0)

-(void)tick:(CADisplayLink *)displayLink
{
    if (nu_valueIsNull(_space))
        return;
    
	NSTimeInterval time = displayLink.timestamp;
	
//    self.space.gravity = cpvmult([Accelerometer getAcceleration], 600);
    id step_func = [_space valueForIvar:@"stepBlock:"];
    if (!nu_valueIsNull(step_func)) {
        execute_block_safely(^{ return [step_func evalWithArguments:nulist([NSNumber numberWithFloat:_timeStep], nil)]; });
    } else {
        [_space step:_timeStep];
    }
	
	BOOL needs_sync = (time - _lastFrameTime > MAX_DT);
	if(!self.isRendering || needs_sync){
		if(needs_sync) [self sync];

        for(ChipmunkShape *shape in _space.shapes){
            [shape drawWithRenderer:_renderer dt:_timeStep];
        }
        
        	for(ChipmunkConstraint *constraint in _space.constraints){
         [constraint drawWithRenderer:_renderer dt:_timeStep];
         }
        
		
		[self display:^{
			[self clear];
			[_renderer render];
		} sync:needs_sync];
		
		_lastFrameTime = time;
	}
	
}



-(cpVect)convertTouch:(UITouch *)touch;
{
	return t_point(_touchTransform, [touch locationInView:touch.view]);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [self.space touchesBegan:touches withEvent:event];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [self.space touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [self.space touchesEnded:touches withEvent:event];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.space touchesCancelled:touches withEvent:event];
}


- (ChipmunkSpace *)space { return _space; }
- (void)setSpace:(ChipmunkSpace *)space
{
    [space retain];
    [_space release];
    _space = space;
    
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setupGL];
}

@end

