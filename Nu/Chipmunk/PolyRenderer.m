#import "PolyRenderer.h"

#import <GLKit/GLKit.h>

#import "transform.h"

#if __ARM_NEON__
#import "arm_neon.h"
#endif

#import <sys/sysctl.h>

#import "ObjectiveChipmunk.h"
#import "ChipmunkHastySpace.h"

#define SHAPE_OUTLINE_WIDTH 1.0
#define SHAPE_OUTLINE_COLOR ((Color){200.0/255.0, 210.0/255.0, 230.0/255.0, 1.0})

#define CONTACT_COLOR ((Color){1.0, 0.0, 0.0, 1.0})

#define CONSTRAINT_DOT_RADIUS 3.0
#define CONSTRAINT_LINE_RADIUS 1.0
#define CONSTRAINT_COLOR ((Color){0.0, 0.75, 0.0, 1.0})

@implementation ChipmunkBody(DemoRenderer)

-(Transform)extrapolatedTransform:(NSTimeInterval)dt
{
	cpBody *body = self.body;
	cpVect pos = cpvadd(body->p, cpvmult(body->v, dt));;
	cpVect rot = cpvforangle(body->a + body->w*dt);
	
	return (Transform){
		rot.x, -rot.y, pos.x,
		rot.y,  rot.x, pos.y,
	};
}

@end


@interface ChipmunkShape()

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
-(Color)color;

@end

@implementation ChipmunkShape(DemoRenderer)

static Color
ColorFromHash(cpHashValue hash, float alpha)
{
	unsigned long val = (unsigned long)hash;
	
	// scramble the bits up using Robert Jenkins' 32 bit integer hash function
	val = (val+0x7ed55d16) + (val<<12);
	val = (val^0xc761c23c) ^ (val>>19);
	val = (val+0x165667b1) + (val<<5);
	val = (val+0xd3a2646c) ^ (val<<9);
	val = (val+0xfd7046c5) + (val<<3);
	val = (val^0xb55a4f09) ^ (val>>16);
	
	GLfloat r = (val>>0) & 0xFF;
	GLfloat g = (val>>8) & 0xFF;
	GLfloat b = (val>>16) & 0xFF;
	
	GLfloat max = MAX(MAX(r, g), b);
	GLfloat min = MIN(MIN(r, g), b);
	GLfloat intensity = 0.75;
	
	// Saturate and scale the color
	if(min == max){
		return RGBAColor(intensity, 0.0, 0.0, alpha);
	} else {
		GLfloat coef = alpha*intensity/(max - min);
		return (Color){
			(r - min)*coef,
			(g - min)*coef,
			(b - min)*coef,
			alpha
		};
	}
}

-(Color)color
{
	// This method uses some private API to detect some states you normally shouldn't care about.
	if(self.sensor){
		return LAColor(0.0, 0.0);
	} else {
		ChipmunkBody *body = self.body;
		
		if(body.isStatic || body.isSleeping){
			return LAColor(0.5, 1.0);
		} else if(body.body->node.idleTime > self.shape->space->sleepTimeThreshold) {
			return LAColor(0.33, 1.0);
		} else {
			return ColorFromHash(self.shape->hashid, 1.0);
		}
	}
}

@end

// TODO add optional line and fill modes?
@implementation ChipmunkCircleShape(DemoRenderer)
-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	cpVect offset = self.offset;
	cpFloat r1 = MAX(self.radius, SHAPE_OUTLINE_WIDTH);
	cpFloat r2 = r1 - SHAPE_OUTLINE_WIDTH;
	
	Transform t = [self.body extrapolatedTransform:dt];
	cpVect pos = t_point(t, offset);
	cpVect end = t_point(t, cpv(offset.x, offset.y + r2));
	
	[renderer drawDot:pos radius:r1 color:SHAPE_OUTLINE_COLOR];
	if(r2 > 0.0) [renderer drawDot:pos radius:r2 color:self.color];
	[renderer drawSegmentFrom:pos to:end radius:SHAPE_OUTLINE_WIDTH color:SHAPE_OUTLINE_COLOR];
}

@end

@interface ChipmunkCircleDotShape : ChipmunkCircleShape
@end
@implementation ChipmunkCircleDotShape
-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
    cpVect pos = cpvadd(self.body.body->p, cpvmult(self.body.body->v, dt));
    [renderer drawDot:pos radius:4.0 color:SHAPE_OUTLINE_COLOR];
}
@end

@implementation ChipmunkSegmentShape(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	Transform t = [self.body extrapolatedTransform:dt];
	cpVect a = t_point(t, self.a);
	cpVect b = t_point(t, self.b);
	
	cpFloat r1 = MAX(self.radius, SHAPE_OUTLINE_WIDTH);
	cpFloat r2 = r1 - SHAPE_OUTLINE_WIDTH;
	
	[renderer drawSegmentFrom:a to:b radius:r1 color:SHAPE_OUTLINE_COLOR];
	if(r2 > 0.0) [renderer drawSegmentFrom:a to:b radius:r2 color:self.color];
}

@end


@implementation ChipmunkPolyShape(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	cpPolyShape *poly = (cpPolyShape *)self.shape;
	
	cpVect *verts = poly->verts;
	NSUInteger count = poly->numVerts;
	
	Transform t = [self.body extrapolatedTransform:dt];
	cpVect tverts[count];
	for(int i=0; i<count; i++){
		tverts[i] = t_point(t, verts[i]);
	}
	
	[renderer drawPolyWithVerts:tverts count:count width:1.0 fill:self.color line:SHAPE_OUTLINE_COLOR];
}

@end


@interface ChipmunkConstraint()

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;

@end


@implementation ChipmunkConstraint(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt {}

@end


@implementation ChipmunkPinJoint(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	cpVect a = [self.bodyA local2world:self.anchr1];
	cpVect b = [self.bodyB local2world:self.anchr2];
	
	[renderer drawDot:a radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawDot:b radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawSegmentFrom:a to:b radius:CONSTRAINT_LINE_RADIUS color:CONSTRAINT_COLOR];
}

@end


@implementation ChipmunkSlideJoint(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	cpVect a = t_point([self.bodyA extrapolatedTransform:dt], self.anchr1);
	cpVect b = t_point([self.bodyB extrapolatedTransform:dt], self.anchr2);
	
	[renderer drawDot:a radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawDot:b radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawSegmentFrom:a to:b radius:CONSTRAINT_LINE_RADIUS color:CONSTRAINT_COLOR];
}

@end


@implementation ChipmunkPivotJoint(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	cpVect a = t_point([self.bodyA extrapolatedTransform:dt], self.anchr1);
	cpVect b = t_point([self.bodyB extrapolatedTransform:dt], self.anchr2);
	
	[renderer drawDot:a radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawDot:b radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
}

@end


@implementation ChipmunkGrooveJoint(DemoRenderer)

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	// Hmm apparently I never made the groove joint properties...
	cpVect a = t_point([self.bodyA extrapolatedTransform:dt], cpGrooveJointGetGrooveA(self.constraint));
	cpVect b = t_point([self.bodyA extrapolatedTransform:dt], cpGrooveJointGetGrooveB(self.constraint));
	cpVect c = t_point([self.bodyB extrapolatedTransform:dt], cpGrooveJointGetAnchr2(self.constraint));
	
	[renderer drawSegmentFrom:a to:b radius:CONSTRAINT_LINE_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawDot:c radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
}

@end


@implementation ChipmunkDampedSpring(DemoRenderer)

static const cpVect SPRING_VERTS[] = {
	{0.00f, 0.0f},
	{0.20f, 0.0f},
	{0.25f, 3.0f},
	{0.30f,-6.0f},
	{0.35f, 6.0f},
	{0.40f,-6.0f},
	{0.45f, 6.0f},
	{0.50f,-6.0f},
	{0.55f, 6.0f},
	{0.60f,-6.0f},
	{0.65f, 6.0f},
	{0.70f,-3.0f},
	{0.75f, 6.0f},
	{0.80f, 0.0f},
	{1.00f, 0.0f},
};
static const int SPRING_COUNT = sizeof(SPRING_VERTS)/sizeof(cpVect);

-(void)drawWithRenderer:(PolyRenderer *)renderer dt:(cpFloat)dt;
{
	cpVect a = t_point([self.bodyA extrapolatedTransform:dt], self.anchr1);
	cpVect b = t_point([self.bodyB extrapolatedTransform:dt], self.anchr2);
	Transform t = t_mult(t_boneScale(a, b), t_scale(1.0, 1.0/cpvdist(a, b)));
	
	cpVect verts[SPRING_COUNT];
	for(int i=0; i<SPRING_COUNT; i++){
		verts[i] = t_point(t, SPRING_VERTS[i]);
	}
	
	for(int i=1; i<SPRING_COUNT; i++){
		[renderer drawSegmentFrom:verts[i-1] to:verts[i] radius:CONSTRAINT_LINE_RADIUS color:CONSTRAINT_COLOR];
	}
	
	[renderer drawDot:a radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
	[renderer drawDot:b radius:CONSTRAINT_DOT_RADIUS color:CONSTRAINT_COLOR];
}

@end



enum {
    UNIFORM_PROJECTION_MATRIX,
//		UNIFORM_TEXTURE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    ATTRIB_COLOR,
    NUM_ATTRIBUTES
};

@interface PolyRenderer(){
	GLuint _program;
//	GLuint _texture;

	GLuint _vao;
	GLuint _vbo;
	
	NSUInteger _vboCapacity;
	NSUInteger _bufferCapacity, _bufferCount;
	Vertex *_buffer;
	
	Transform _projection;
}

@end


@implementation PolyRenderer

@synthesize projection = _projection;

-(void)setProjection:(Transform)projection
{
	NSAssert([EAGLContext currentContext], @"No GL context set!");
	
	_projection = projection;
	
	glUseProgram(_program);
	Matrix mat = t_matrix(_projection);
	glUniformMatrix4fv(uniforms[UNIFORM_PROJECTION_MATRIX], 1, GL_FALSE, mat.m);
}

//MARK: Shaders

// TODO get rid of this gross shader loading code code
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader %@", file);
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
	NSAssert([EAGLContext currentContext], @"No GL context set!");
	
	GLint logLength, status;
	
	glValidateProgram(prog);
	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
			GLchar *log = (GLchar *)malloc(logLength);
			glGetProgramInfoLog(prog, logLength, &logLength, log);
			NSLog(@"Program validate log:\n%s", log);
			free(log);
	}
	
	glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
	if (status == 0) {
			return NO;
	}
	
	return YES;
}

- (BOOL)loadShaders
{
	NSAssert([EAGLContext currentContext], @"No GL context set!");
	
	GLuint vertShader, fragShader;
	NSString *vertShaderPathname, *fragShaderPathname;
	
	// Create shader program.
	_program = glCreateProgram();
	
	// Create and compile vertex shader.
	vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"AntialiasedShader.vsh" ofType:nil];
	if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
			NSLog(@"Failed to compile vertex shader %@", vertShaderPathname);
			return NO;
	}
	
	// Create and compile fragment shader.
	fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"AntialiasedShader.fsh" ofType:nil];
	if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
			NSLog(@"Failed to compile fragment shader");
			return NO;
	}
	
	// Attach vertex shader to program.
	glAttachShader(_program, vertShader);
	
	// Attach fragment shader to program.
	glAttachShader(_program, fragShader);
	
	// Bind attribute locations.
	// This needs to be done prior to linking.
	glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
	glBindAttribLocation(_program, ATTRIB_TEXCOORD, "texcoord");
	glBindAttribLocation(_program, ATTRIB_COLOR, "color");
	
	// Link program.
	if (![self linkProgram:_program]) {
			NSLog(@"Failed to link program: %d", _program);
			
			if (vertShader) {
					glDeleteShader(vertShader);
					vertShader = 0;
			}
			if (fragShader) {
					glDeleteShader(fragShader);
					fragShader = 0;
			}
			if (_program) {
					glDeleteProgram(_program);
					_program = 0;
			}
			
			return NO;
	}
	
	// Get uniform locations.
	uniforms[UNIFORM_PROJECTION_MATRIX] = glGetUniformLocation(_program, "projection");
//    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(_program, "texture");
	
	// Release vertex and fragment shaders.
	if (vertShader) {
			glDetachShader(_program, vertShader);
			glDeleteShader(vertShader);
	}
	if (fragShader) {
			glDetachShader(_program, fragShader);
			glDeleteShader(fragShader);
	}
	
	return YES;
}

//MARK: Memory

-(void)ensureCapacity:(NSUInteger)count
{
	if(_bufferCount + count > _bufferCapacity){
		_bufferCapacity += MAX(_bufferCapacity, count);
		_buffer = realloc(_buffer, _bufferCapacity*sizeof(Vertex));
		
//		NSLog(@"Resized vertex buffer to %d", _bufferCapacity);
	}
}

-(id)initWithProjection:(Transform)projection;
{
	if((self = [super init])){
		NSAssert([EAGLContext currentContext], @"No GL context set!");
    [self loadShaders];
		
		glUseProgram(_program);
		self.projection = projection;
		
//		glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
		
//		NSURL *texture_url = [[NSBundle mainBundle] URLForResource:@"gradient.png" withExtension:nil];
//		
//		NSError *error = nil;
//		GLKTextureInfo *tex_info = [GLKTextureLoader textureWithContentsOfURL:texture_url
//			options:[NSDictionary dictionaryWithObjectsAndKeys:
//				[NSNumber numberWithBool:TRUE], GLKTextureLoaderGenerateMipmaps,
//				[NSNumber numberWithBool:TRUE], GLKTextureLoaderOriginBottomLeft,
//				[NSNumber numberWithBool:TRUE], GLKTextureLoaderGrayscaleAsAlpha,
//				nil]
//			error:&error
//		];
//		
//		if(error){
//			NSLog(@"%@", error);
//		}
//		
//		_texture = tex_info.name;
//		glBindTexture(GL_TEXTURE_2D, _texture);
//		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
//		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glGenVertexArraysOES(1, &_vao);
    glBindVertexArrayOES(_vao);
		
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
		[self ensureCapacity:512];
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, vertex));
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, texcoord));
    
    glEnableVertexAttribArray(ATTRIB_COLOR);
    glVertexAttribPointer(ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, color));
    
    glBindVertexArrayOES(0);
		PRINT_GL_ERRORS();
	}
	
	return self;
}

-(void)dealloc
{
	NSAssert([EAGLContext currentContext], @"No GL context set!");
	
	free(_buffer); _buffer = 0;
	
	glDeleteProgram(_program); _program = 0;
//	glDeleteTextures(1, &_texture); _texture = 0;
	glDeleteBuffers(1, &_vbo); _vbo = 0;
	glDeleteVertexArraysOES(1, &_vao); _vao = 0;
}

//MARK: Immediate Mode

-(void)drawDot:(cpVect)pos radius:(cpFloat)radius color:(Color)color;
{
	NSUInteger vertex_count = 2*3;
	[self ensureCapacity:vertex_count];
	
	Vertex a = {{pos.x - radius, pos.y - radius}, {-1.0, -1.0}, color};
	Vertex b = {{pos.x - radius, pos.y + radius}, {-1.0,  1.0}, color};
	Vertex c = {{pos.x + radius, pos.y + radius}, { 1.0,  1.0}, color};
	Vertex d = {{pos.x + radius, pos.y - radius}, { 1.0, -1.0}, color};
	
	Triangle *triangles = (Triangle *)(_buffer + _bufferCount);
	triangles[0] = (Triangle){a, b, c};
	triangles[1] = (Triangle){a, c, d};
	
	_bufferCount += vertex_count;
}

-(void)drawSegmentFrom:(cpVect)a to:(cpVect)b radius:(cpFloat)radius color:(Color)color;
{
	NSUInteger vertex_count = 6*3;
	[self ensureCapacity:vertex_count];
	
	cpVect n = cpvnormalize(cpvperp(cpvsub(b, a)));
	cpVect t = cpvperp(n);
	
	cpVect nw = cpvmult(n, radius);
	cpVect tw = cpvmult(t, radius);
	cpVect v0 = cpvsub(b, cpvadd(nw, tw));
	cpVect v1 = cpvadd(b, cpvsub(nw, tw));
	cpVect v2 = cpvsub(b, nw);
	cpVect v3 = cpvadd(b, nw);
	cpVect v4 = cpvsub(a, nw);
	cpVect v5 = cpvadd(a, nw);
	cpVect v6 = cpvsub(a, cpvsub(nw, tw));
	cpVect v7 = cpvadd(a, cpvadd(nw, tw));
	
	Triangle *triangles = (Triangle *)(_buffer + _bufferCount);
	triangles[0] = (Triangle){{v0, cpvneg(cpvadd(n, t)), color}, {v1, cpvsub(n, t), color}, {v2, cpvneg(n), color},};
	triangles[1] = (Triangle){{v3, n, color}, {v1, cpvsub(n, t), color}, {v2, cpvneg(n), color},};
	triangles[2] = (Triangle){{v3, n, color}, {v4, cpvneg(n), color}, {v2, cpvneg(n), color},};
	triangles[3] = (Triangle){{v3, n, color}, {v4, cpvneg(n), color}, {v5, n, color},};
	triangles[4] = (Triangle){{v6, cpvsub(t, n), color}, {v4, cpvneg(n), color}, {v5, n, color},};
	triangles[5] = (Triangle){{v6, cpvsub(t, n), color}, {v7, cpvadd(n, t), color}, {v5, n, color},};
	
	_bufferCount += vertex_count;
}

-(void)drawPolyWithVerts:(cpVect *)verts count:(NSUInteger)count width:(cpFloat)width fill:(Color)fill line:(Color)line;
{
	struct ExtrudeVerts {cpVect offset, n;};
	struct ExtrudeVerts extrude[count];
	bzero(extrude, sizeof(struct ExtrudeVerts)*count);
	
	for(int i=0; i<count; i++){
		cpVect v0 = verts[(i-1+count)%count];
		cpVect v1 = verts[i];
		cpVect v2 = verts[(i+1)%count];
		
		cpVect n1 = cpvnormalize(cpvperp(cpvsub(v1, v0)));
		cpVect n2 = cpvnormalize(cpvperp(cpvsub(v2, v1)));
		
		cpVect offset = cpvmult(cpvadd(n1, n2), 1.0/(cpvdot(n1, n2) + 1.0));
		extrude[i] = (struct ExtrudeVerts){offset, n2};
	}
	
	BOOL outline = TRUE;//(line.a > 0.0 && width > 0.0);
	
	NSUInteger triangle_count = 3*count - 2;
	NSUInteger vertex_count = 3*triangle_count;
	[self ensureCapacity:vertex_count];
	
	Triangle *triangles = (Triangle *)(_buffer + _bufferCount);
	Triangle *cursor = triangles;
	
	cpFloat inset = (outline == 0.0 ? 0.5 : 0.0);
	for(int i=0; i<count-2; i++){
		cpVect v0 = cpvsub(verts[0  ], cpvmult(extrude[0  ].offset, inset));
		cpVect v1 = cpvsub(verts[i+1], cpvmult(extrude[i+1].offset, inset));
		cpVect v2 = cpvsub(verts[i+2], cpvmult(extrude[i+2].offset, inset));
		
		*cursor++ = (Triangle){{v0, cpvzero, fill}, {v1, cpvzero, fill}, {v2, cpvzero, fill},};
	}
	
	for(int i=0; i<count; i++){
		int j = (i+1)%count;
		cpVect v0 = verts[i];
		cpVect v1 = verts[j];
		
		cpVect n0 = extrude[i].n;
		
		cpVect offset0 = extrude[i].offset;
		cpVect offset1 = extrude[j].offset;
		
		if(outline){
			cpVect inner0 = cpvsub(v0, cpvmult(offset0, width));
			cpVect inner1 = cpvsub(v1, cpvmult(offset1, width));
			cpVect outer0 = cpvadd(v0, cpvmult(offset0, width));
			cpVect outer1 = cpvadd(v1, cpvmult(offset1, width));
			
			*cursor++ = (Triangle){{inner0, cpvneg(n0), line}, {inner1, cpvneg(n0), line}, {outer1, n0, line}};
			*cursor++ = (Triangle){{inner0, cpvneg(n0), line}, {outer0, n0, line}, {outer1, n0, line}};
		} else {
			cpVect inner0 = cpvsub(v0, cpvmult(offset0, 0.5));
			cpVect inner1 = cpvsub(v1, cpvmult(offset1, 0.5));
			cpVect outer0 = cpvadd(v0, cpvmult(offset0, 0.5));
			cpVect outer1 = cpvadd(v1, cpvmult(offset1, 0.5));
			
			*cursor++ = (Triangle){{inner0, cpvzero, fill}, {inner1, cpvzero, fill}, {outer1, n0, fill}};
			*cursor++ = (Triangle){{inner0, cpvzero, fill}, {outer0, n0, fill}, {outer1, n0, fill}};
		}
	}
	
	_bufferCount += vertex_count;
}

//MARK: Rendering

-(void)render
{
	NSAssert([EAGLContext currentContext], @"No GL context set!");
	
	glBindBuffer(GL_ARRAY_BUFFER, _vbo);
	
	if(_bufferCapacity != _vboCapacity){
		glBufferData(GL_ARRAY_BUFFER, sizeof(Vertex)*_bufferCapacity, NULL, GL_STREAM_DRAW);
		_vboCapacity = _bufferCapacity;
	}
	
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(Vertex)*_bufferCount, _buffer);
		
//	glActiveTexture(GL_TEXTURE0);
//	glBindTexture(GL_TEXTURE_2D, _texture);
	
	glUseProgram(_program);
	glBindVertexArrayOES(_vao);
	glDrawArrays(GL_TRIANGLES, 0, _bufferCount);
	
	_bufferCount = 0;
	PRINT_GL_ERRORS();
}

@end
