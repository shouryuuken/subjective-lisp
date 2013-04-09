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


#define GRABABLE_MASK_BIT (1<<31)
#define NOT_GRABABLE_MASK (~GRABABLE_MASK_BIT)


@interface ChipmunkGlue : NSObject
@end

@implementation ChipmunkGlue

static inline cpFloat frand(){return (cpFloat)arc4random()/(cpFloat)UINT32_MAX;}
static inline cpFloat frand_unit(){return 2.0f*frand() - 1.0f;}

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
    static BOOL is_initialized = NO;
    if (is_initialized) {
        return;
    }
    is_initialized = YES;
    
    install_builtin(@"cp", @"CP_ALL_LAYERS", [NSNumber numberWithUnsignedInt:CP_ALL_LAYERS]);
    install_builtin(@"cp", @"GRABABLE_MASK_BIT", [NSNumber numberWithUnsignedInt:GRABABLE_MASK_BIT]);
    install_builtin(@"cp", @"NOT_GRABABLE_MASK", [NSNumber numberWithUnsignedLong:NOT_GRABABLE_MASK]);
    install_builtin(@"cp", @"cpfinfinity", [NSNumber numberWithFloat:INFINITY]);
    install_builtin(@"cp", @"cpfpi", [NSNumber numberWithFloat:M_PI]);
    install_builtin(@"cp", @"cpfe", [NSNumber numberWithFloat:M_E]);
    
    install_static_func(@"cp",  cpfsqrt, "cpfsqrt", "ff");
    install_static_func(@"cp", cpfsin, "cpfsin", "ff");
    install_static_func(@"cp", cpfcos, "cpfcos", "ff");
    install_static_func(@"cp", cpfacos, "cpfacos", "ff");
    install_static_func(@"cp", cpfatan2, "cpfatan2", "fff");
    install_static_func(@"cp", cpfmod, "cpfmod", "fff");
    install_static_func(@"cp", cpfexp, "cpfexp", "ff");
    install_static_func(@"cp", cpfpow, "cpfpow", "fff");
    install_static_func(@"cp", cpffloor, "cpffloor", "ff");
    install_static_func(@"cp", cpfceil, "cpfceil", "ff");
    install_static_func(@"cp", cpfmax, "cpfmax", "fff");
    install_static_func(@"cp", cpfmin, "cpfmin", "fff");
    install_static_func(@"cp", cpfabs, "cpfabs", "ff");
    install_static_func(@"cp", cpfclamp, "cpfclamp", "ffff");
    install_static_func(@"cp", cpfclamp01, "cpfclamp01", "ff");
    install_static_func(@"cp", cpflerp, "cpflerp", "ffff");
    install_static_func(@"cp", cpflerpconst, "cpflerpconst", "ffff");

    install_static_func(@"cp", cpveql, "cpveql", "i{?=ff}{?=ff}");
    install_static_func(@"cp", cpvadd, "cpvadd", "{?=ff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpvsub, "cpvsub", "{?=ff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpvneg, "cpvneg", "{?=ff}{?=ff}");
    install_static_func(@"cp", cpvmult, "cpvmult", "{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvdot, "cpvdot", "f{?=ff}{?=ff}");
    install_static_func(@"cp", cpvcross, "cpvcross", "f{?=ff}{?=ff}");
    install_static_func(@"cp", cpvperp, "cpvperp", "{?=ff}{?=ff}");
    install_static_func(@"cp", cpvrperp, "cpvrperp", "{?=ff}{?=ff}");
    install_static_func(@"cp", cpvproject, "cpvproject", "{?=ff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpvrotate, "cpvrotate", "{?=ff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpvunrotate, "cpvunrotate", "{?=ff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpvlength, "cpvlength", "f{?=ff}");
    install_static_func(@"cp", cpvlengthsq, "cpvlengthsq", "f{?=ff}");
    install_static_func(@"cp", cpvlerp, "cpvlerp", "{?=ff}{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvlerpconst, "cpvlerpconst", "{?=ff}{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvslerp, "cpvslerp", "{?=ff}{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvslerpconst, "cpvslerpconst", "{?=ff}{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvnormalize_safe, "cpvnormalize", "{?=ff}{?=ff}");
    install_static_func(@"cp", cpvclamp, "cpvclamp", "{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvdist, "cpvdist", "f{?=ff}{?=ff}");
    install_static_func(@"cp", cpvdistsq, "cpvdistsq", "f{?=ff}{?=ff}");
    install_static_func(@"cp", cpvnear, "cpvnear", "i{?=ff}{?=ff}f");
    install_static_func(@"cp", cpvforangle, "cpvforangle", "{?=ff}f");
    install_static_func(@"cp", cpvtoangle, "cpvtoangle", "f{?=ff}");
    
    install_static_func(@"cp", cpBBNew, "cp-new-bb", "{?=ffff}ffff");
    install_static_func(@"cp", cpBBNewForCircle, "cp-new-bb-for-circle", "{?=ffff}{?=ff}f");

    install_static_func(@"cp", cpBBIntersects, "cp-bb-intersects-bb", "i{?=ffff}{?=ffff}");
    install_static_func(@"cp", cpBBContainsBB, "cp-bb-contains-bb", "i{?=ffff}{?=ffff}");
    install_static_func(@"cp", cpBBContainsVect, "cp-bb-contains-vect", "i{?=ffff}{?=ff}");
    install_static_func(@"cp", cpBBMerge, "cp-merge-bb", "{?=ffff}{?=ffff}{?=ffff}");
    install_static_func(@"cp", cpBBExpand, "cp-expand-bb", "{?=ffff}{?=ffff}{?=ff}");
    install_static_func(@"cp", cpBBArea, "cp-bb-area", "f{?=ffff}");
    install_static_func(@"cp", cpBBMergedArea, "cp-bb-merged-area", "f{?=ffff}{?=ffff}");
    install_static_func(@"cp", cpBBSegmentQuery, "cp-bb-segment-query", "f{?=ffff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpBBIntersectsSegment, "cp-bb-intersects-segment", "i{?=ffff}{?=ff}{?=ff}");
    install_static_func(@"cp", cpBBClampVect, "cp-bb-clamp-vect", "{?=ff}{?=ffff}{?=ff}");
    install_static_func(@"cp", cpBBWrapVect, "cp-bb-wrap-vect", "{?=ff}{?=ffff}{?=ff}");
        
    install_static_func(@"cp", cpMomentForCircle, "cp-moment-for-circle", "ffff{?=ff}");
    install_static_func(@"cp", cpMomentForSegment, "cp-moment-for-segment", "ff{?=ff}{?=ff}");
    install_static_func(@"cp", cpMomentForPolyHelper, "cp-moment-for-poly", "ff@{?=ff}");
    install_static_func(@"cp", cpMomentForBox, "cp-moment-for-box", "ffff");

    install_static_func(@"cp", cpAreaForCircle, "cp-area-for-circle", "fff");
    install_static_func(@"cp", cpAreaForSegment, "cp-area-for-segment", "f{?=ff}{?=ff}f");
//    nufn("cp-area-for-poly", cpAreaForPoly, "f
//    cpFloat cpAreaForPoly(const int numVerts, const cpVect *verts)
    
    install_static_func(@"cp", cpResetShapeIdCounter, "cp-reset-shape-id-counter", "v");
    
    install_static_func(@"cp", frand, "frand", "f");
    install_static_func(@"cp", frand_unit, "frand-unit", "f");
    install_static_func(@"cp", frand_unit_circle, "frand-unit-circle", "{?=ff}");
    
}

@end

@implementation ChipmunkSpace(Nu)

- (void)useSpatialHash:(cpFloat)dim count:(int)count
{
    cpSpaceUseSpatialHash(self.space, dim, count);
}

- (id) handleUnknownMessage:(id)cdr withContext:(NSMutableDictionary *)context
{
    void (^__block func)(id lst) = ^(id lst) {
        for (id elt in lst) {
            if (nu_objectIsKindOfClass(elt, [NSArray class])) {
                func(elt);
            } else if (!nu_valueIsNull(elt)) {
                [self add:elt];
            }
        }
    };
    for (id elt in cdr) {
        id value = [elt evalWithContext:context];
        if (nu_objectIsKindOfClass(value, [NSArray class])) {
            func(value);
        } else if (nu_objectIsKindOfClass(value, [ChipmunkBody class])
                   || nu_objectIsKindOfClass(value, [ChipmunkShape class])
                   || nu_objectIsKindOfClass(value, [ChipmunkConstraint class])) {
            [self add:value];
        } else {
            prn([NSString stringWithFormat:@"ChipmunkSpace: trying to add invalid object %@", value]);
        }
    }
    return self;
}

-(bool)absorbPreSolve:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
{
    cpFloat DENSITY = (1.0e-2);
    
    // Get the two colliding shapes
    CHIPMUNK_ARBITER_GET_SHAPES(arbiter, ball1, ball2);
    ChipmunkCircleShape *bigger = (id)ball1;
    ChipmunkCircleShape *smaller = (id)ball2;
    
    if(smaller.radius > bigger.radius){
        ChipmunkCircleShape *tmp = bigger;
        bigger = smaller;
        smaller = tmp;
    }
    
    cpFloat r1 = bigger.radius;
    cpFloat r2 = smaller.radius;
    cpFloat area = r1*r1 + r2*r2;
    cpFloat dist = cpfmax(cpvdist(bigger.body.pos, smaller.body.pos), cpfsqrt(area));
    
    cpFloat r1_new = (2.0*dist + cpfsqrt(8.0*area - 4.0*dist*dist))/4.0;
    
    // First update the velocity by gaining the absorbed momentum.
    cpFloat old_mass = bigger.body.mass;
    cpFloat new_mass = r1_new*r1_new*DENSITY;
    cpFloat gained_mass = new_mass - old_mass;
    bigger.body.vel = cpvmult(cpvadd(cpvmult(bigger.body.vel, old_mass), cpvmult(smaller.body.vel, gained_mass)), 1.0/new_mass);
    
    bigger.body.mass = new_mass;
    cpCircleShapeSetRadius(bigger.shape, r1_new);
    [[bigger valueForIvar:@"sprite"] setScale:r1_new*3/256.0];
    
    cpFloat r2_new = dist - r1_new;
    if(r2_new > 0.0){
        smaller.body.mass = r2_new*r2_new*DENSITY;
        cpCircleShapeSetRadius(smaller.shape, r2_new);
        [[smaller valueForIvar:@"sprite"] setScale:r2_new*3/256.0];
    } else {
        // If smart remove is called from within a callback
        // it will schedule a post-step callback to perform the removal automatically.
        // NICE!
        [[smaller valueForIvar:@"sprite"] removeFromParent];
        [space smartRemove:smaller];
        [space smartRemove:smaller.body];
    }
    
    return FALSE;
}

- (id)callCollisionDelegate:(NSString *)key arbiter:(cpArbiter *)arbiter space:(ChipmunkSpace *)space
{
    CP_ARBITER_GET_SHAPES(arbiter, aa, bb);
    id a = aa->data;
    id b = bb->data;
    id block = [self valueForKey:@"collisionBlock"];
    if (block) {
        return execute_block_safely(^{
            return [block evalWithArguments:nulist(key, space, a, b, nil)];
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

- (void)addCollisionDelegateA:(id)a b:(id)b begin:(SEL)begin pre:(SEL)pre post:(SEL)post separate:(SEL)separate
{
    [self addCollisionHandler:self typeA:a typeB:b begin:begin preSolve:pre postSolve:post separate:separate];
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

#import "cocos2d.h"


@interface CCPhysicsParticle : CCParticleSystemQuad
@property (nonatomic, assign) BOOL ignoreBodyRotation;
@property (nonatomic, assign) cpBody *body;
@property (nonatomic, assign) ChipmunkBody *chipmunkBody;
@end

@implementation CCPhysicsParticle

@synthesize ignoreBodyRotation = _ignoreBodyRotation;
@synthesize body = _body;

-(ChipmunkBody *)chipmunkBody
{
    if (!_body)
        return nil;
    return (ChipmunkBody *) _body->data;
}

-(void)setChipmunkBody:(ChipmunkBody *)chipmunkBody
{
	_body = chipmunkBody.body;
}
// Override the setters and getters to always reflect the body's properties.
-(CGPoint)position
{
    if (!_body)
        return [super position];
    return cpBodyGetPos(_body);
}

-(void)setPosition:(CGPoint)position
{
    if (!_body) {
        [super setPosition:position];
    } else {
        cpBodySetPos(_body, position);
    }
}

-(float)rotation
{
    if (!_body) {
        return [super rotation];
    }
    return (_ignoreBodyRotation ? super.rotation : -CC_RADIANS_TO_DEGREES(cpBodyGetAngle(_body)));
}

-(void)setRotation:(float)rotation
{
    if (!_body) {
        return [super setRotation:rotation];
    }
    if(_ignoreBodyRotation){
        super.rotation = rotation;
    } else {
        cpBodySetAngle(_body, -CC_DEGREES_TO_RADIANS(rotation));
    }
}

// returns the transform matrix according the Chipmunk Body values
-(CGAffineTransform) nodeToParentTransform
{
    if (!_body) {
        return [super nodeToParentTransform];
    }
    
    cpVect rot = (_ignoreBodyRotation ? cpvforangle(-CC_DEGREES_TO_RADIANS(_rotationX)) : _body->rot);
    rot.x *= _scaleX; rot.y *= _scaleY;
    CGFloat x = _body->p.x + rot.x*-_anchorPointInPoints.x - rot.y*-_anchorPointInPoints.y;
    CGFloat y = _body->p.y + rot.y*-_anchorPointInPoints.x + rot.x*-_anchorPointInPoints.y;
	
    if(_ignoreAnchorPointForPosition){
		x += _anchorPointInPoints.x;
		y += _anchorPointInPoints.y;
	}
	
	return (_transform = CGAffineTransformMake(rot.x, rot.y, -rot.y,	rot.x, x,	y));
}


// this method will only get called if the sprite is batched.
// return YES if the physic's values (angles, position ) changed.
// If you return NO, then nodeToParentTransform won't be called.
-(BOOL) dirty
{
	return YES;
}


@end
