//
//  PerthGlue.m
//  Nu
//
//  Created by arthur on 25/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdint.h>

#include "perthgtfs.h"
#import "Nu.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface PerthGlue : NSObject
@end

@implementation PerthGlue
+ (MKCoordinateRegion)MKCoordinateRegionMakeWithDistance:(CLLocationCoordinate2D)centerCoordinate
                                                     lat:(CLLocationDistance)latitudinalMeters
                                                     lon:(CLLocationDistance)longitudinalMeters
{
    return MKCoordinateRegionMakeWithDistance(centerCoordinate, latitudinalMeters, longitudinalMeters);
}
                                                      

int int_bounds(int val, int min, int max)
{
    if (val < min)
        return -1;
    if (val > max)
        return -1;
    return val;
}

gtfs_agency_t *agency_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_AGENCIES_NELTS-1) < 0)
        return NULL;
    return &gtfs_agencies[idx];
}

int agency_index_with_id(uint32_t agency_id)
{
    for(int i=0; i<GTFS_AGENCIES_NELTS; i++) {
        gtfs_agency_t *elt = &gtfs_agencies[i];
        if (agency_id == elt->agency_id)
            return i;
    }
    return -1;
}

NuCell *agency_to_nu(int idx, id append)
{
    gtfs_agency_t *elt = agency_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->agency_id);
    cursor = nu_cell_cons_str(cursor, elt->agency_name);
    return lst;
}

NuCell *agency_id_to_nu(int agency_id, id append)
{
    return agency_to_nu(agency_index_with_id(agency_id), append);
}

gtfs_calendar_t *calendar_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_CALENDAR_NELTS-1) < 0)
        return NULL;
    return &gtfs_calendar[idx];
}

int calendar_with_id(uint32_t service_id)
{
    for(int i=0; i<GTFS_CALENDAR_NELTS; i++) {
        gtfs_calendar_t *elt = &gtfs_calendar[i];
        if (service_id == elt->service_id)
            return i;
    }
    return -1;
}

NuCell *calendar_to_nu(int idx, id append)
{
    gtfs_calendar_t *elt = calendar_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->service_id);
    for(int i=0; i<7; i++) {
        cursor = nu_cell_cons_uint8(cursor, elt->dayofweek[i]);
    }
    cursor = nu_cell_cons_uint16(cursor, elt->start_year);
    cursor = nu_cell_cons_uint8(cursor, elt->start_month);
    cursor = nu_cell_cons_uint8(cursor, elt->start_day);
    cursor = nu_cell_cons_uint16(cursor, elt->end_year);
    cursor = nu_cell_cons_uint8(cursor, elt->end_month);
    cursor = nu_cell_cons_uint8(cursor, elt->end_day);
    return lst;
}

NuCell *calendar_id_to_nu(int service_id, id append)
{
    return calendar_to_nu(calendar_with_id(service_id), append);
}

gtfs_calendar_date_t *calendardate_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_CALENDAR_DATES_NELTS-1) < 0)
        return NULL;
    return &gtfs_calendar_dates[idx];
}

NuCell *calendardate_to_nu(int idx, id append)
{
    gtfs_calendar_date_t *elt = calendardate_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->service_id);
    cursor = nu_cell_cons_uint16(cursor, elt->date_year);
    cursor = nu_cell_cons_uint8(cursor, elt->date_month);
    cursor = nu_cell_cons_uint8(cursor, elt->date_day);
    cursor = nu_cell_cons_uint8(cursor, elt->exception_type);
    return lst;
}

gtfs_custom_landmark_t *landmark_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_CUSTOM_LANDMARKS_NELTS-1) < 0)
        return NULL;
    return &gtfs_custom_landmarks[idx];
}

int landmark_with_id(uint32_t landmark_id)
{
    for(int i=0; i<GTFS_CUSTOM_LANDMARKS_NELTS; i++) {
        gtfs_custom_landmark_t *elt = &gtfs_custom_landmarks[i];
        if (landmark_id == elt->landmark_id)
            return i;
    }
    return -1;
}

NuCell *landmark_to_nu(int idx, id append)
{
    gtfs_custom_landmark_t *elt = landmark_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->landmark_id);
    cursor = nu_cell_cons_str(cursor, elt->landmark_name);
    cursor = nu_cell_cons_double(cursor, elt->landmark_pt_lat);
    cursor = nu_cell_cons_double(cursor, elt->landmark_pt_lon);
    cursor = nu_cell_cons_uint32(cursor, elt->landmark_typeid);
    cursor = nu_cell_cons_str(cursor, elt->landmark_typename);
    return lst;
}

NuCell *landmark_id_to_nu(int landmark_id, id append)
{
    return landmark_to_nu(landmark_with_id(landmark_id), append);
}

gtfs_route_t *route_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_ROUTES_NELTS-1) < 0)
        return NULL;
    return &gtfs_routes[idx];
}

int route_with_id(uint32_t route_id)
{
    for(int i=0; i<GTFS_ROUTES_NELTS; i++) {
        gtfs_route_t *elt = &gtfs_routes[i];
        if (route_id == elt->route_id)
            return i;
    }
    return -1;
}

NuCell *route_to_nu(int idx, id append)
{
    gtfs_route_t *elt = route_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->route_id);
    cursor = nu_cell_cons_uint32(cursor, elt->agency_id);
    cursor = nu_cell_cons_str(cursor, elt->route_short_name);
    cursor = nu_cell_cons_str(cursor, elt->route_long_name);
    cursor = nu_cell_cons_uint8(cursor, elt->route_type);
    return lst;
}

NuCell *route_id_to_nu(int route_id, id append)
{
    return route_to_nu(route_with_id(route_id), append);
}

gtfs_stop_time_t *stoptime_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_STOP_TIMES_NELTS-1) < 0)
        return NULL;
    return &gtfs_stop_times[idx];
}

NuCell *stoptime_to_nu(int idx, id append)
{
    gtfs_stop_time_t *elt = stoptime_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->trip_id);
    cursor = nu_cell_cons_uint8(cursor, elt->arrival_hour);
    cursor = nu_cell_cons_uint8(cursor, elt->arrival_min);
    cursor = nu_cell_cons_uint8(cursor, elt->arrival_sec);
    cursor = nu_cell_cons_uint8(cursor, elt->departure_hour);
    cursor = nu_cell_cons_uint8(cursor, elt->departure_min);
    cursor = nu_cell_cons_uint8(cursor, elt->departure_sec);
    cursor = nu_cell_cons_uint32(cursor, elt->stop_id);
    cursor = nu_cell_cons_uint32(cursor, elt->stop_sequence);
    cursor = nu_cell_cons_uint8(cursor, elt->pickup_type);
    cursor = nu_cell_cons_uint8(cursor, elt->drop_off_type);
    cursor = nu_cell_cons_double(cursor, elt->shape_dist_traveled);
    return lst;
}

gtfs_stop_t *stop_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_STOPS_NELTS-1) < 0)
        return NULL;
    return &gtfs_stops[idx];
}

int stop_with_id(uint32_t stop_id)
{
    for(int i=0; i<GTFS_STOPS_NELTS; i++) {
        gtfs_stop_t *elt = &gtfs_stops[i];
        if (stop_id == elt->stop_id)
            return i;
    }
    return -1;
}

NuCell *stop_to_nu(int idx, id append)
{
    gtfs_stop_t *elt = stop_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint8(nil, elt->location_type);
    cursor = nu_cell_cons_uint32(cursor, elt->parent_station);
    cursor = nu_cell_cons_uint32(cursor, elt->stop_id);
    cursor = nu_cell_cons_uint32(cursor, elt->stop_code);
    cursor = nu_cell_cons_str(cursor, elt->stop_name);
    cursor = nu_cell_cons_str(cursor, elt->stop_desc);
    cursor = nu_cell_cons_double(cursor, elt->stop_lat);
    cursor = nu_cell_cons_double(cursor, elt->stop_lon);
    if (append)
        cursor = nu_cell_cons(cursor, append);
    return lst;
}

NuCell *stop_id_to_nu(int stop_id, id append)
{
    return stop_to_nu(stop_with_id(stop_id), append);
}

gtfs_trip_t *trip_with_index(int idx)
{
    if (int_bounds(idx, 0, GTFS_TRIPS_NELTS-1) < 0)
        return NULL;
    return &gtfs_trips[idx];
}

int trip_with_id(uint32_t trip_id)
{
    for(int i=0; i<GTFS_TRIPS_NELTS; i++) {
        gtfs_trip_t *elt = &gtfs_trips[i];
        if (trip_id == elt->trip_id)
            return i;
    }
    return -1;
}

NuCell *trip_to_nu(int idx, id append)
{
    gtfs_trip_t *elt = trip_with_index(idx);
    if (!elt)
        return nil;
    NuCell *lst, *cursor;
    lst = cursor = nu_cell_cons_uint32(nil, elt->route_id);
    cursor = nu_cell_cons_uint32(cursor, elt->service_id);
    cursor = nu_cell_cons_uint32(cursor, elt->trip_id);
    cursor = nu_cell_cons_str(cursor, elt->trip_headsign);
    cursor = nu_cell_cons_uint32(cursor, elt->shape_id);
    return lst;
}

NuCell *trip_id_to_nu(int trip_id, id append)
{
    return trip_to_nu(trip_with_id(trip_id), append);
}

NuCell *gtfs_dict_to_nu(NSDictionary *dict, id (*nufunc)(int idx, id obj), NSComparator sortfunc)
{
    NSArray *arr = [dict allKeys];
    if (sortfunc) {
        arr = [arr sortedArrayUsingComparator:sortfunc];
    }
    NuCell *lst=nil, *cursor=nil;
    for (NSNumber *idx in arr) {
        cursor = nu_cell_cons(cursor, nufunc([idx intValue], [dict objectForKey:idx]));
        if (!lst)
            lst = cursor;
    }
    return lst;
}


NSArray *stops_for_location(CLLocation *loc, double metres)
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    for (int i=0; i<GTFS_STOPS_NELTS; i++) {
        gtfs_stop_t *elt = &gtfs_stops[i];
        double val = [loc distanceFromLocation:[[[CLLocation alloc] initWithLatitude:elt->stop_lat longitude:elt->stop_lon] autorelease]];
        if (val <= metres) {
            [dict setObject:[NSNumber numberWithDouble:val] forKey:[NSNumber numberWithInt:i]];
            NSLog(@"closestStop: %.0f", val);
        }
    }
    NSArray *sortedarr = [[dict allKeys] sortedArrayUsingComparator:^(id aa, id bb) {
        double a = [(NSNumber *)[dict objectForKey:aa] doubleValue];
        double b = [(NSNumber *)[dict objectForKey:bb] doubleValue];
        if (a < b) return NSOrderedAscending;
        if (a > b) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    for (NSNumber *idx_obj in sortedarr) {
        int idx = [idx_obj intValue];
        [arr addObject:stop_to_nu(idx, [dict objectForKey:idx_obj])];
    }
    return arr;
}
+ (NSArray *)stopsForLocation:(CLLocation *)loc range:(double)metres { return stops_for_location(loc, metres); }

NSArray *stops_for_region(MKCoordinateRegion region)
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    CLLocationCoordinate2D ul_coord = CLLocationCoordinate2DMake(region.center.latitude-region.span.latitudeDelta/2.0, region.center.longitude-region.span.longitudeDelta/2.0);
    CLLocationCoordinate2D lr_coord = CLLocationCoordinate2DMake(region.center.latitude+region.span.latitudeDelta/2.0, region.center.longitude+region.span.longitudeDelta/2.0);
    MKMapPoint ul_mappoint = MKMapPointForCoordinate(ul_coord);
    MKMapPoint lr_mappoint = MKMapPointForCoordinate(lr_coord);
    MKMapRect region_maprect = MKMapRectMake(fmin(ul_mappoint.x, lr_mappoint.x),
                                             fmin(ul_mappoint.y, lr_mappoint.y),
                                             fabs(ul_mappoint.x - lr_mappoint.x),
                                             fabs(ul_mappoint.y - lr_mappoint.y));
    for (int i=0; i<GTFS_STOPS_NELTS; i++) {
        gtfs_stop_t *elt = &gtfs_stops[i];
        if (elt->parent_station)
            continue;
        CLLocationCoordinate2D stop_coord = CLLocationCoordinate2DMake(elt->stop_lat, elt->stop_lon);
        MKMapPoint stop_mappoint = MKMapPointForCoordinate(stop_coord);
        if (MKMapRectContainsPoint(region_maprect, stop_mappoint)) {
            [dict setObject:[NSNumber numberWithInt:1] forKey:[NSNumber numberWithInt:i]];
        }
    }
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    for (NSNumber *idx_obj in [dict allKeys]) {
        int idx = [idx_obj intValue];
        [arr addObject:stop_to_nu(idx, nil)];
    }
    return arr;
}
+ (NSArray *)stopsForRegion:(MKCoordinateRegion)region { return stops_for_region(region); }


NSMutableDictionary *stoptimes_for_stop_id(int stop_id)
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    for(int i=0; i<GTFS_STOP_TIMES_NELTS; i++) {
        gtfs_stop_time_t *elt = &gtfs_stop_times[i];
        if (stop_id == elt->stop_id) {
            [dict setObject:[NSNumber numberWithInt:1] forKey:[NSNumber numberWithInt:i]];
        }
    }
    return dict;
}

NSMutableDictionary *stoptimes_for_stop(int idx)
{
    gtfs_stop_t *stop = stop_with_index(idx);
    if (stop)
        return stoptimes_for_stop_id(stop->stop_id);
    return nil;
}
        
NSMutableDictionary *trip_ids_for_stoptimes(NSArray *stoptimes)
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSNumber *idx_obj in stoptimes) {
        int idx = [idx_obj intValue];
        gtfs_stop_time_t *stoptime = stoptime_with_index(idx);
        [dict setObject:[NSNumber numberWithInt:1] forKey:[NSNumber numberWithUnsignedInt:stoptime->trip_id]];
    }
    return dict;
}

NSMutableDictionary *route_ids_for_trip_ids(NSArray *trips)
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSNumber *trip_id_obj in trips) {
        int trip_id = [trip_id_obj unsignedIntValue];
        int trip_idx = trip_with_id(trip_id);
        if (trip_idx < 0)
            continue;
        gtfs_trip_t *trip = trip_with_index(trip_idx);
        [dict setObject:[NSNumber numberWithInt:1] forKey:[NSNumber numberWithUnsignedInt:trip->route_id]];
    }
    return dict;
}

+ (int)nagencies { return GTFS_AGENCIES_NELTS; }
+ (NuCell *)agency:(int)idx { return agency_to_nu(idx, nil); }
+ (int)ncalendar { return GTFS_CALENDAR_NELTS; }
+ (NuCell *)calendar:(int)idx { return calendar_to_nu(idx, nil); }
+ (int)ncalendardates { return GTFS_CALENDAR_DATES_NELTS; }
+ (NuCell *)calendardate:(int)idx { return calendardate_to_nu(idx, nil); }
+ (int)nlandmarks { return GTFS_CUSTOM_LANDMARKS_NELTS; }
+ (NuCell *)landmark:(int)idx { return landmark_to_nu(idx, nil); }
+ (int)nroutes { return GTFS_ROUTES_NELTS; }
+ (NuCell *)route:(int)idx { return route_to_nu(idx, nil); }
+ (int)nstoptimes { return GTFS_STOP_TIMES_NELTS; }
+ (NuCell *)stoptime:(int)idx { return stoptime_to_nu(idx, nil); }
+ (int)nstops { return GTFS_STOPS_NELTS; }
+ (NuCell *)stop:(int)idx { return stop_to_nu(idx, nil); }
+ (int)ntrips { return GTFS_TRIPS_NELTS; }
+ (NuCell *)trip:(int)idx { return trip_to_nu(idx, nil); }

+ (NuCell *)agenciesWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, agency_to_nu, nil); }
+ (NuCell *)calendarWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, calendar_to_nu, nil); }
+ (NuCell *)calendardatesWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, calendardate_to_nu, nil); }
+ (NuCell *)landmarksWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, landmark_to_nu, nil); }
+ (NuCell *)routesWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, route_to_nu, nil); }
+ (NuCell *)stoptimesWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, stoptime_to_nu, nil); }
+ (NuCell *)stopsWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, stop_to_nu, nil); }
+ (NuCell *)tripsWithDict:(NSDictionary *)dict { return gtfs_dict_to_nu(dict, trip_to_nu, nil); }

/*
+ (NSDictionary *)stopsForLocation:(CLLocation *)loc range:(double)metres { return stops_for_location(loc, metres); }
+ (NuCell *)stopsByDistance:(NSDictionary *)dict { return stops_by_distance(dict); }
+ (NSDictionary *)stoptimesForStop:(int)idx { return stoptimes_for_stop(idx); }
+ (NSDictionary *)tripIdsForStoptimes:(NSDictionary *)dict { return trip_ids_for_stoptimes([dict allKeys]); }
+ (NSDictionary *)routeIdsForTripIds:(NSDictionary *)dict { return route_ids_for_trip_ids([dict allKeys]); }
+ (NSDictionary *)stoptimesForStopId:(uint32_t)stop_id { return stoptimes_for_stop_id(stop_id); }
+ (NuCell *)tripsForLocation:(CLLocation *)loc range:(double)metres
{
    return gtfs_dict_to_nu(trip_ids_for_stops(stops_for_location(loc, metres)), trip_id_to_nu, nil);
}
+ (NuCell *)routesForLocation:(CLLocation *)loc range:(double)metres 
{
    return gtfs_dict_to_nu(route_ids_for_stops(stops_for_location(loc, metres)), route_id_to_nu, nil);
}
*/

@end

@interface GTFSAnnotation : NSObject
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subtitle;
@end

@implementation GTFSAnnotation
@synthesize coordinate = _coordinate;
@synthesize title = _title;
@synthesize subtitle = _subtitle;

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass: [GTFSAnnotation class]])
        return NO;
    GTFSAnnotation *a = other;
    return ((a.coordinate.latitude == self.coordinate.latitude)
            && (a.coordinate.longitude == self.coordinate.longitude));
}

@end
