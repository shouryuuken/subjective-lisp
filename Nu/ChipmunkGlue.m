//
//  ChipmunkGlue.m
//  Nu
//
//  Created by arthur on 28/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


#import "Nu.h"
#import "chipmunk_unsafe.h"

/*
 NuCell *make_nu_list(id obj, ...)
 {
 va_list args;
 va_start(args, obj);
 NuCell *list = [[[NuCell alloc] init] autorelease];
 id cursor = list;
 [cursor setCar:obj];
 id elt;
 for(;;) {
 elt = va_arg(args, id);
 if (!elt)
 break;
 [cursor setCdr:[[[NuCell alloc] init] autorelease]];
 cursor = [cursor cdr];
 [cursor setCar:obj];
 }
 va_end(args);
 return list;
 }
 
 NuPointer *make_nu_pointer(void *ptr)
 {
 id nupointer = [[[NuPointer alloc] init] autorelease];
 [nupointer setPointer:ptr];
 [nupointer setTypeString:[NSString stringWithCString:"^v" encoding:NSUTF8StringEncoding]];
 return nupointer;
 }
*/

void nusym(char *name, id obj)
{
    NuSymbolTable *symbolTable = [NuSymbolTable sharedSymbolTable];    
    [(NuSymbol *)[symbolTable symbolWithString:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]] setValue:obj];
}

void nufn(char *name, void *fn, char *signature)
{
    nusym(name, [[[NuBridgedFunction alloc] initWithStaticFunction:fn name:name signature:signature] autorelease]);
}


#define GRABABLE_MASK_BIT (1<<31)
#define NOT_GRABABLE_MASK (~GRABABLE_MASK_BIT)


@interface ChipmunkGlue : NSObject
@end

@implementation ChipmunkGlue

static inline cpFloat
frand(void)
{
	return (cpFloat)rand()/(cpFloat)RAND_MAX;
}

static cpVect
frand_unit_circle()
{
	cpVect v = cpv(frand()*2.0f - 1.0f, frand()*2.0f - 1.0f);
	return (cpvlengthsq(v) < 1.0f ? v : frand_unit_circle());
}

cpVect *new_cpvect_array(id lst)
{
    int n = [lst count];
    cpVect *buf = malloc(n * sizeof(cpVect));
    for(int i=0; i<n; i++) {
        buf[i] = [[lst objectAtIndex:i] cpVectValue];
    }
    return buf;
}

//cpFloat cpMomentForPoly(cpFloat m, int numVerts, const cpVect *verts, cpVect offset)
cpFloat cpMomentForPolyHelper(cpFloat m, id verts, cpVect offset)
{
    int nverts = [verts count];
    cpVect *verts_buf = new_cpvect_array(verts);
    cpFloat result = cpMomentForPoly(m, nverts, verts_buf, offset);
    free(verts_buf);
    return result;
}

+ (void)bindings
{
    nusym("GRABABLE_MASK_BIT", [NSNumber numberWithUnsignedInt:GRABABLE_MASK_BIT]);
    nusym("NOT_GRABABLE_MASK", [NSNumber numberWithUnsignedLong:NOT_GRABABLE_MASK]);
    nusym("cpfinfinity", [NSNumber numberWithFloat:INFINITY]);
    nusym("cpfpi", [NSNumber numberWithFloat:M_PI]);
    nusym("cpfe", [NSNumber numberWithFloat:M_E]);
    
    nufn("cpfsqrt", cpfsqrt, "ff");
    nufn("cpfsin", cpfsin, "ff");
    nufn("cpfcos", cpfcos, "ff");
    nufn("cpfacos", cpfacos, "ff");
    nufn("cpfatan2", cpfatan2, "fff");
    nufn("cpfmod", cpfmod, "fff");
    nufn("cpfexp", cpfexp, "ff");
    nufn("cpfpow", cpfpow, "fff");
    nufn("cpffloor", cpffloor, "ff");
    nufn("cpfceil", cpfceil, "ff");
    nufn("cpfmax", cpfmax, "fff");
    nufn("cpfmin", cpfmin, "fff");
    nufn("cpfabs", cpfabs, "ff");
    nufn("cpfclamp", cpfclamp, "ffff");
    nufn("cpfclamp01", cpfclamp01, "ff");
    nufn("cpflerp", cpflerp, "ffff");
    nufn("cpflerpconst", cpflerpconst, "ffff");

    nufn("cpveql", cpveql, "i{?=ff}{?=ff}");
    nufn("cpvadd", cpvadd, "{?=ff}{?=ff}{?=ff}");
    nufn("cpvsub", cpvsub, "{?=ff}{?=ff}{?=ff}");
    nufn("cpvneg", cpvneg, "{?=ff}{?=ff}");
    nufn("cpvmult", cpvmult, "{?=ff}{?=ff}f");
    nufn("cpvdot", cpvdot, "f{?=ff}{?=ff}");
    nufn("cpvcross", cpvcross, "f{?=ff}{?=ff}");
    nufn("cpvperp", cpvperp, "{?=ff}{?=ff}");
    nufn("cpvrperp", cpvrperp, "{?=ff}{?=ff}");
    nufn("cpvproject", cpvproject, "{?=ff}{?=ff}{?=ff}");
    nufn("cpvrotate", cpvrotate, "{?=ff}{?=ff}{?=ff}");
    nufn("cpvunrotate", cpvunrotate, "{?=ff}{?=ff}{?=ff}");
    nufn("cpvlength", cpvlength, "f{?=ff}");
    nufn("cpvlengthsq", cpvlengthsq, "f{?=ff}");
    nufn("cpvlerp", cpvlerp, "{?=ff}{?=ff}{?=ff}f");
    nufn("cpvlerpconst", cpvlerpconst, "{?=ff}{?=ff}{?=ff}f");
    nufn("cpvslerp", cpvslerp, "{?=ff}{?=ff}{?=ff}f");
    nufn("cpvslerpconst", cpvslerpconst, "{?=ff}{?=ff}{?=ff}f");
    nufn("cpvnormalize", cpvnormalize_safe, "{?=ff}{?=ff}");
    nufn("cpvclamp", cpvclamp, "{?=ff}{?=ff}f");
    nufn("cpvdist", cpvdist, "f{?=ff}{?=ff}");
    nufn("cpvdistsq", cpvdistsq, "f{?=ff}{?=ff}");
    nufn("cpvnear", cpvnear, "i{?=ff}{?=ff}f");
    nufn("cpvforangle", cpvforangle, "{?=ff}f");
    nufn("cpvtoangle", cpvtoangle, "f{?=ff}");
    
    nufn("cp-new-bb", cpBBNew, "{?=ffff}ffff");
    nufn("cp-new-bb-for-circle", cpBBNewForCircle, "{?=ffff}{?=ff}f");

    nufn("cp-bb-intersects-bb", cpBBIntersects, "i{?=ffff}{?=ffff}");
    nufn("cp-bb-contains-bb", cpBBContainsBB, "i{?=ffff}{?=ffff}");
    nufn("cp-bb-contains-vect", cpBBContainsVect, "i{?=ffff}{?=ff}");
    nufn("cp-merge-bb", cpBBMerge, "{?=ffff}{?=ffff}{?=ffff}");
    nufn("cp-expand-bb", cpBBExpand, "{?=ffff}{?=ffff}{?=ff}");
    nufn("cp-bb-area", cpBBArea, "f{?=ffff}");
    nufn("cp-bb-merged-area", cpBBMergedArea, "f{?=ffff}{?=ffff}");
    nufn("cp-bb-segment-query", cpBBSegmentQuery, "f{?=ffff}{?=ff}{?=ff}");
    nufn("cp-bb-intersects-segment", cpBBIntersectsSegment, "i{?=ffff}{?=ff}{?=ff}");
    nufn("cp-bb-clamp-vect", cpBBClampVect, "{?=ff}{?=ffff}{?=ff}");
    nufn("cp-bb-wrap-vect", cpBBWrapVect, "{?=ff}{?=ffff}{?=ff}");
        
    nufn("cp-moment-for-circle", cpMomentForCircle, "ffff{?=ff}");
    nufn("cp-moment-for-segment", cpMomentForSegment, "ff{?=ff}{?=ff}");
    nufn("cp-moment-for-poly", cpMomentForPolyHelper, "ff@{?=ff}");
    nufn("cp-moment-for-box", cpMomentForBox, "ffff");

    nufn("cp-area-for-circle", cpAreaForCircle, "fff");
    nufn("cp-area-for-segment", cpAreaForSegment, "f{?=ff}{?=ff}f");
//    nufn("cp-area-for-poly", cpAreaForPoly, "f
//    cpFloat cpAreaForPoly(const int numVerts, const cpVect *verts)
    
    nufn("cp-reset-shape-id-counter", cpResetShapeIdCounter, "v");
    
    nufn("frand", frand, "f");
    nufn("frand-unit-circle", frand_unit_circle, "{?=ff}");
    
}

@end

@implementation ChipmunkSpace(Nu)

- (void)useSpatialHash:(cpFloat)dim count:(int)count
{
    cpSpaceUseSpatialHash(self.space, dim, count);
}

- (id) handleUnknownMessage:(NuCell *)cdr withContext:(NSMutableDictionary *)context
{
    for (id obj in cdr) {
        id result = [obj evalWithContext:context];
        if (result)
            [self add:result];
    }
    return cdr;
}

- (id)touchesDelegate
{
    return [self valueForIvar:@"touchesDelegate"];
}

- (void)setTouchesDelegate:(id)obj
{
    [self setValue:obj forIvar:@"touchesDelegate"];
}

- (id)callCollisionDelegate:(NSString *)key arbiter:(cpArbiter *)arbiter space:(ChipmunkSpace *)space
{
    CP_ARBITER_GET_SHAPES(arbiter, aa, bb);
    id a = aa->data;
    id b = bb->data;
    id typea = [a collisionType];
    id typeb = [b collisionType];
    id collisionDelegate = [typea valueForIvar:@"collisionDelegate"];
    id delegate = [collisionDelegate valueForKey:(NSString *)typeb];
    id block = [delegate valueForKey:key];
    if (!nu_valueIsNull(block)) {
        return execute_block_safely(^{
            return [block evalWithArguments:nulist(space, a, b, nil)];
        });
    }
    return nil;
}

- (bool)collisionBegin:(cpArbiter *)arbiter space:(ChipmunkSpace *)space
{
    id result = [self callCollisionDelegate:@"begin" arbiter:arbiter space:space];
    return (nu_valueIsNull(result)) ? FALSE : TRUE;
}

- (bool)collisionPreSolve:(cpArbiter *)arbiter space:(ChipmunkSpace *)space
{
    id result = [self callCollisionDelegate:@"pre" arbiter:arbiter space:space];
    return (nu_valueIsNull(result)) ? FALSE : TRUE;
}

- (void)collisionPostSolve:(cpArbiter *)arbiter space:(ChipmunkSpace *)space
{
    [self callCollisionDelegate:@"post" arbiter:arbiter space:space];
}

- (void)collisionSeparate:(cpArbiter *)arbiter space:(ChipmunkSpace *)space
{
    [self callCollisionDelegate:@"separate" arbiter:arbiter space:space];
}

- (void)addCollisionDelegateA:(id)a b:(id)b
{
    [self addCollisionHandler:self typeA:a typeB:b begin:@selector(collisionBegin:space:) preSolve:@selector(collisionPreSolve:space:) postSolve:@selector(collisionPostSolve:space:) separate:@selector(collisionSeparate:space:)];
}

@end


@implementation ChipmunkBody(Nu)

+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"mass"];
    cpFloat mass = (obj) ? [obj floatValue] : INFINITY;
    obj = [prop consumeKey:@"moment"];
    cpFloat moment = (obj) ? [obj floatValue] : INFINITY;
    obj = [self bodyWithMass:mass andMoment:moment];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}

static void
cpBodyVelocityFuncHelper(cpBody *_body, cpVect gravity, cpFloat damping, cpFloat dt)
{
    ChipmunkBody *body = _body->data;
    id block = [body valueForIvar:@"velocityFunc"];
    if (!block)
        return;
    execute_block_safely(^{
        return [block evalWithArguments:nulist(
            body,
            nulist(get_symbol_value(@"list"), [NSNumber numberWithFloat:gravity.x], [NSNumber numberWithFloat:gravity.y], nil),
                                        [NSNumber numberWithFloat:damping],
                                        [NSNumber numberWithFloat:dt],
                                        nil)];
    });
}

static void
PlanetGravityVelocityFunc(cpBody *body, cpVect gravity, cpFloat damping, cpFloat dt)
{
    // Gravitational acceleration is proportional to the inverse square of
    // distance, and directed toward the origin. The central planet is assumed
    // to be massive enough that it affects the satellites but not vice versa.
    cpVect pos = cpBodyGetPos(body);
    cpFloat sqdist = cpvlengthsq(pos);
    cpVect g = cpvmult(pos, -5.0e6/(sqdist*cpfsqrt(sqdist)));
    
    cpBodyUpdateVelocity(body, g, damping, dt);
}

- (void)setVelocityFunc:(id)obj
{
    if (nu_objectIsKindOfClass(obj, [NuBlock class])) {
        [self setValue:obj forIvar:@"velocityFunc"];
        self.body->velocity_func = cpBodyVelocityFuncHelper;
    } else if ([obj isEqual:@"PlanetGravityVelocityFunc"]) {
        self.body->velocity_func = PlanetGravityVelocityFunc;
    } else {
        self.body->velocity_func = cpBodyUpdateVelocity;
    }
}

- (void)updateVelocity:(cpVect)gravity damping:(cpFloat)damping dt:(cpFloat)dt
{
    cpBodyUpdateVelocity([self body], gravity, damping, dt);
}

@end

@implementation ChipmunkCircleShape(Nu)

+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"body"];
    if (!obj)
        return nil;
    id body = obj;
    obj = [prop consumeKey:@"radius"];
    cpFloat radius = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"offset"];
    cpVect offset = (obj) ? [obj cpVectValue] : cpv(0.0, 0.0);
    obj = [self circleWithBody:body radius:radius offset:offset];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}

- (void)unsafeSetRadius:(cpFloat)radius
{
                        cpCircleShapeSetRadius(self.shape, radius);
}

@end
@implementation ChipmunkPolyShape(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    if ([prop valueForKey:@"body"] && [prop valueForKey:@"width"] && [prop valueForKey:@"height"]) {
        id body = [prop consumeKey:@"body"];
        cpFloat width = [[prop consumeKey:@"width"] floatValue];
        cpFloat height = [[prop consumeKey:@"height"] floatValue];
        id obj = [self boxWithBody:body width:width height:height];
        [obj setValuesForKeysWithDictionary:prop];
        return obj;
    }
    if ([prop valueForKey:@"body"] && [prop valueForKey:@"bb"]) {
        id body = [prop consumeKey:@"body"];
        cpBB bb = [[prop consumeKey:@"bb"] cpBBValue];
        id obj = [self boxWithBody:body bb:bb];
        [obj setValuesForKeysWithDictionary:prop];
        return obj;
    }
    if ([prop valueForKey:@"body"] && [prop valueForKey:@"verts"]) {
        id body = [prop consumeKey:@"body"];
        id verts = [prop consumeKey:@"verts"];
        cpVect offset = [[prop consumeKey:@"offset"] cpVectValue];
        int nverts = [verts count];
        cpVect *verts_buf = new_cpvect_array(verts);
        id obj = [self polyWithBody:body count:nverts verts:verts_buf offset:offset];
        free(verts_buf);
        [obj setValuesForKeysWithDictionary:prop];
        return obj;
    }
    return nil;
}
@end

@implementation ChipmunkSegmentShape(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"body"];
    if (!obj)
        return nil;
    id body = obj;
    obj = [prop consumeKey:@"from"];
    cpVect from = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"to"];
    cpVect to = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"radius"];
    cpFloat radius = (obj) ? [obj floatValue] : 0.0;
    obj = [self segmentWithBody:body from:from to:to radius:radius];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkRotaryLimitJoint(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"a"];
    if (!obj)
        return nil;
    id a = obj;
    obj = [prop consumeKey:@"b"];
    if (!obj)
        return nil;
    id b = obj;
    obj = [prop consumeKey:@"min"];
    cpFloat min = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"max"];
    cpFloat max = (obj) ? [obj floatValue] : 0.0;
    obj = [self rotaryLimitJointWithBodyA:a bodyB:b min:min max:max];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkPivotJoint(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    if ([prop valueForKey:@"a"] && [prop valueForKey:@"b"] && [prop valueForKey:@"pivot"]) {
        id a = [prop consumeKey:@"a"];
        id b = [prop consumeKey:@"b"];
        cpVect pivot = [[prop consumeKey:@"pivot"] cpVectValue];
        id obj = [self pivotJointWithBodyA:a bodyB:b pivot:pivot];
        [obj setValuesForKeysWithDictionary:prop];
        return obj;
    }
    if ([prop valueForKey:@"a"] && [prop valueForKey:@"b"] && [prop valueForKey:@"anchr1"] && [prop valueForKey:@"anchr2"]) {
        id a = [prop consumeKey:@"a"];
        id b = [prop consumeKey:@"b"];
        cpVect anchr1 = [[prop consumeKey:@"anchr1"] cpVectValue];
        cpVect anchr2 = [[prop consumeKey:@"anchr2"] cpVectValue];
        id obj = [self pivotJointWithBodyA:a bodyB:b anchr1:anchr1 anchr2:anchr2];
        [obj setValuesForKeysWithDictionary:prop];
        return obj;
    }
    return nil;
}
@end

@implementation ChipmunkDampedSpring(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"a"];
    if (!obj)
        return nil;
    id a = obj;
    obj = [prop consumeKey:@"b"];
    if (!obj)
        return nil;
    id b = obj;
    obj = [prop consumeKey:@"anchr1"];
    cpVect anchr1 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"anchr2"];
    cpVect anchr2 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"restLength"];
    cpFloat restLength = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"stiffness"];
    cpFloat stiffness = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"damping"];
    cpFloat damping = (obj) ? [obj floatValue] : 0.0;
    obj = [self dampedSpringWithBodyA:a bodyB:b anchr1:anchr1 anchr2:anchr2 restLength:restLength stiffness:stiffness damping:damping];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkPinJoint(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"a"];
    if (!obj)
        return nil;
    id a = obj;
    obj = [prop consumeKey:@"b"];
    if (!obj)
        return nil;
    id b = obj;
    obj = [prop consumeKey:@"anchr1"];
    cpVect anchr1 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"anchr2"];
    cpVect anchr2 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [self pinJointWithBodyA:a bodyB:b anchr1:anchr1 anchr2:anchr2];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkGearJoint(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"a"];
    if (!obj)
        return nil;
    id a = obj;
    obj = [prop consumeKey:@"b"];
    if (!obj)
        return nil;
    id b = obj;
    obj = [prop consumeKey:@"phase"];
    cpFloat phase = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"ratio"];
    cpFloat ratio = (obj) ? [obj floatValue] : 0.0;
    obj = [self gearJointWithBodyA:a bodyB:b phase:phase ratio:ratio];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkGrooveJoint(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"a"];
    if (!obj)
        return nil;
    id a = obj;
    obj = [prop consumeKey:@"b"];
    if (!obj)
        return nil;
    id b = obj;
    obj = [prop consumeKey:@"start"];
    cpVect start = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"end"];
    cpVect end = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"anchr2"];
    cpVect anchr2 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [self grooveJointWithBodyA:a bodyB:b groove_a:start groove_b:end anchr2:anchr2];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkSlideJoint(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"a"];
    if (!obj)
        return nil;
    id a = obj;
    obj = [prop consumeKey:@"b"];
    if (!obj)
        return nil;
    id b = obj;
    obj = [prop consumeKey:@"anchr1"];
    cpVect anchr1 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"anchr2"];
    cpVect anchr2 = (obj) ? [obj cpVectValue] : cpvzero;
    obj = [prop consumeKey:@"min"];
    cpFloat min = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"max"];
    cpFloat max = (obj) ? [obj floatValue] : INFINITY;
    obj = [self slideJointWithBodyA:a bodyB:b anchr1:anchr1 anchr2:anchr2 min:min max:max];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkMultiGrab(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"space"];
    if (!obj)
        return nil;
    id space = obj;
    obj = [prop consumeKey:@"smoothing"];
    cpFloat smoothing = (obj) ? [obj floatValue] : 0.0;
    obj = [prop consumeKey:@"grabForce"];
    cpFloat grabForce = (obj) ? [obj floatValue] : 0.0;
    obj = [[[self alloc] initForSpace:space withSmoothing:smoothing withGrabForce:grabForce] autorelease];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}
@end

@implementation ChipmunkConstraint(Nu)

static void
cpConstraintPreSolveFuncHelper(cpConstraint *_constraint, cpSpace *_space)
{
    ChipmunkConstraint *constraint = _constraint->data;
    id block = [constraint valueForIvar:@"preSolveFunc"];
    if (!block)
        return;
    execute_block_safely(^{
        return [block evalWithArguments:nulist(constraint, _space->data, nil)];
    });
}


static void
cpConstraintPostSolveFuncHelper(cpConstraint *_constraint, cpSpace *_space)
{
    static id cached = nil;
    if (!_constraint) {
        cached = nil;
        return;
    }
    ChipmunkConstraint *constraint = _constraint->data;
    if (!cached) {
        id block = [constraint valueForIvar:@"postSolveFunc"];
        if (nu_valueIsNull(block))
            return;
        cached = block;
    }
    execute_block_safely(^{
        return [cached evalWithArguments:nulist(constraint, _space->data, nil)];
    });
}

- (void)setPreSolveFunc:(id)obj
{
    if (nu_objectIsKindOfClass(obj, [NuBlock class])) {
        [self setValue:obj forIvar:@"preSolveFunc"];
        cpConstraintSetPreSolveFunc(self.constraint, cpConstraintPreSolveFuncHelper);
    } else {
        cpConstraintSetPreSolveFunc(self.constraint, NULL);
    }
}

- (void)setPostSolveFunc:(id)obj
{
    if (nu_objectIsKindOfClass(obj, [NuBlock class])) {
        [self setValue:obj forIvar:@"postSolveFunc"];
        cpConstraintSetPostSolveFunc(self.constraint, cpConstraintPostSolveFuncHelper);
    } else {
        cpConstraintSetPostSolveFunc(self.constraint, NULL);
        cpConstraintPostSolveFuncHelper(NULL, NULL);
    }
}

- (cpFloat)impulse
{
    return cpConstraintGetImpulse(self.constraint);
}

@end
