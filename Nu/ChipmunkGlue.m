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
#import "ObjectiveChipmunk.h"

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



@interface ChipmunkGlue : NSObject
@end

@implementation ChipmunkGlue

+ (void)bindings
{    
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
//    nufn("cp-moment-for-poly", cpMomentForPoly, "ff
//cpFloat cpMomentForPoly(cpFloat m, int numVerts, const cpVect *verts, cpVect offset)
    nufn("cp-moment-for-box", cpMomentForBox, "ffff");

    nufn("cp-area-for-circle", cpAreaForCircle, "fff");
    nufn("cp-area-for-segment", cpAreaForSegment, "f{?=ff}{?=ff}f");
//    nufn("cp-area-for-poly", cpAreaForPoly, "f
//    cpFloat cpAreaForPoly(const int numVerts, const cpVect *verts)
    
    nufn("cp-reset-shape-id-counter", cpResetShapeIdCounter, "v");    
}

@end




