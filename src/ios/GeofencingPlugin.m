/*
 * JBoss, Home of Professional Open Source.
 * Copyright Red Hat, Inc., and individual contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

 #define systemSoundID    1003

#import <CoreLocation/CoreLocation.h>
#import "GeofencingPlugin.h"
#import <AudioToolbox/AudioServices.h>

@implementation GeofencingPlugin

@synthesize callbackId;
@synthesize message;
@synthesize locationManager;
@synthesize monitoringRegions;
@synthesize insideRegions;


- (CDVPlugin*)initWithWebView:(UIWebView*)theWebView {
    self = (GeofencingPlugin*)[super initWithWebView:(UIWebView*)theWebView];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self; // Tells the location manager to send updates to this object
    }

    [self.locationManager startUpdatingLocation];
      // Set location accuracy levels
    [locationManager setDesiredAccuracy:kCLLocationAccuracyBest];

    self.monitoringRegions = [[NSMutableSet alloc]init];
    self.insideRegions = [[NSMutableSet alloc] init];
    
    //setup sound effect
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"Beep" withExtension:@"aiff"];
    if (fileURL != nil)
    {
        SystemSoundID theSoundID;
        OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)fileURL, &theSoundID);
        if (error == kAudioServicesNoError)
            soundId = theSoundID;
    }
    return self;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation{
    
    NSLog(@"NEW LOCATION lat %f lon %f ", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
    NSLog(@"OLD LOCATION lat %f lon %f ", oldLocation.coordinate.latitude, oldLocation.coordinate.longitude);
    
    CLLocation *aUserLocation = newLocation;

    //TODO Place in synchronized block
    for (CLRegion *region in  self.monitoringRegions) {
        if([region containsCoordinate:aUserLocation.coordinate]){
            
            if (![self.insideRegions containsObject:region]) {
                [self.insideRegions addObject:region];
                [self notify:region withStatus:@"entered Region"];
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
                
                [self playSoundAlert];
            }
        } else {
            
            if ([self.insideRegions containsObject:region]) {
                [self.insideRegions removeObject:region];
                [self notify:region withStatus:@"leaving Region"];
            }
        
        }
        
    }


}

- (void)register:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *options = [self parseParameters:command];
    self.callbackId = [options objectForKey:@"callback"];

    self.message = [options objectForKey:@"notifyMessage"];
    [self returnStatusOk:command];
}

- (void)addRegion:(CDVInvokedUrlCommand *)command {
    [self checkMonitoringStatus];

    NSMutableDictionary *options = [self parseParameters:command];
    NSString *regionId = [options objectForKey:@"fid"];
    NSString *latitude = [options objectForKey:@"latitude"];
    NSString *longitude = [options objectForKey:@"longitude"];
    double radius = [[options objectForKey:@"radius"] doubleValue];
    if (radius > locationManager.maximumRegionMonitoringDistance) {
        radius = locationManager.maximumRegionMonitoringDistance;
    }

    CLLocationCoordinate2D coordinate2D = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
    CLRegion * region = [[CLRegion alloc] initCircularRegionWithCenter:coordinate2D radius:radius identifier:[NSString stringWithFormat:@"cordovaGeofencing:%@", regionId]];
    [self.monitoringRegions addObject:region];
    [self returnStatusOk:command];
}

- (void)removeRegion:(CDVInvokedUrlCommand *)command {
    NSString *regionId = [[self parseParameters:command] objectForKey:@"fid"];

    BOOL removed = NO;
    for (CLRegion *region in [self monitoringRegions]){
        if ([region.identifier hasSuffix:regionId]) {
            [monitoringRegions removeObject:region];
            removed = YES;
        }
    }
    
    NSLog(@"GeoFence Region Removed %@", removed ? @"Yes" : @"No");
    
    for (CLRegion *region in [self insideRegions]){
        if ([region.identifier hasSuffix:regionId]) {
            [insideRegions removeObject:region];
        }
    }
    [self returnStatusOk:command];
}

- (void)getWatchedRegionIds:(CDVInvokedUrlCommand *)command {
    NSSet *regions = [locationManager monitoredRegions];
    NSMutableArray *watchedRegions = [NSMutableArray array];
    for (CLRegion *region in regions) {
        [watchedRegions addObject:[self getRegionId:region]];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:watchedRegions];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)getRegionId:(CLRegion *)region {
    NSString *identifier = region.identifier;
    return [identifier substringFromIndex:[identifier rangeOfString:@":"].location + 1];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    [self notify:region withStatus:@"entered"];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    [self notify:region withStatus:@"left"];
}

- (void)notify:(CLRegion *)region withStatus:(NSString *)status{
    NSString *regionId = [self getRegionId:region];

    NSString *json = [NSString stringWithFormat:@"{fid:\"%@\",status:\"%@\"}", regionId, status];
    NSString * jsCallBack = [NSString stringWithFormat:@"%@(%@);", self.callbackId, json];
    [self.webView stringByEvaluatingJavaScriptFromString:jsCallBack];

    //Local notification if the app is in the background
    NSString *statusMessage;
    if (message != Nil) {
        statusMessage = [NSString stringWithFormat:message, regionId, status];
    } else {
        statusMessage = [NSString stringWithFormat:@"You have %@ your point of interest", status];
    }

    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate date];
    NSTimeZone* timezone = [NSTimeZone defaultTimeZone];
    notification.timeZone = timezone;
    notification.alertBody = statusMessage;
    notification.alertAction = @"Show";
    notification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSLog(@"starting monitoring region: %@", region);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"Region monitoring failed with error: %@", [error localizedDescription]);
}

- (void)checkMonitoringStatus {
    if (![self isLocationServicesEnabled]) {
        [self returnLocationError:PERMISSIONDENIED withMessage:@"Location services are not enabled."];
        return;
    }

    if (![self isAuthorized]) {
        NSString *errorMessage = nil;
        BOOL authStatusAvailable = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]; // iOS 4.2+
        if (authStatusAvailable) {
            NSUInteger code = [CLLocationManager authorizationStatus];
            if (code == kCLAuthorizationStatusNotDetermined) {
                // could return POSITION_UNAVAILABLE but need to coordinate with other platforms
                errorMessage = @"User undecided on application's use of location services.";
            } else if (code == kCLAuthorizationStatusRestricted) {
                errorMessage = @"Application's use of location services is restricted.";
            }
        }
        // PERMISSIONDENIED is only PositionError that makes sense when authorization denied
        [self returnLocationError:PERMISSIONDENIED withMessage:errorMessage];

        return;
    }

    if (![self isRegionMonitoringEnabled]) {
        [self returnLocationError:GEOFENCINGPERMISSIONDENIED withMessage:@"Geofencing services are not authorized."];
    }
}

- (BOOL)isAuthorized {
    BOOL authorizationStatusClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]; // iOS 4.2+

    if (authorizationStatusClassPropertyAvailable) {
        NSUInteger authStatus = [CLLocationManager authorizationStatus];
        return (authStatus == kCLAuthorizationStatusAuthorized) || (authStatus == kCLAuthorizationStatusNotDetermined);
    }

    // by default, assume YES (for iOS < 4.2)
    return YES;
}

- (BOOL)isLocationServicesEnabled {
    BOOL locationServicesEnabledInstancePropertyAvailable = [self.locationManager respondsToSelector:@selector(locationServicesEnabled)]; // iOS 3.x
    BOOL locationServicesEnabledClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(locationServicesEnabled)]; // iOS 4.x

    if (locationServicesEnabledClassPropertyAvailable) { // iOS 4.x
        return [CLLocationManager locationServicesEnabled];
    } else if (locationServicesEnabledInstancePropertyAvailable) { // iOS 2.x, iOS 3.x
        return [(id) self.locationManager locationServicesEnabled];
    } else {
        return NO;
    }
}

- (BOOL)isRegionMonitoringEnabled {
    if ([CLLocationManager respondsToSelector:@selector(regionMonitoringEnabled)]) {
        return [CLLocationManager regionMonitoringEnabled];
    }
    if ([CLLocationManager respondsToSelector:@selector(regionMonitoringAvailable)]) {
        return [CLLocationManager regionMonitoringAvailable];
    }

    // by default, assume NO
    return NO;
}

- (void)returnStatusOk:(CDVInvokedUrlCommand *)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)returnLocationError:(NSUInteger)errorCode withMessage:(NSString *)errorMessage {
    NSMutableDictionary *posError = [NSMutableDictionary dictionaryWithCapacity:2];

    [posError setObject:[NSNumber numberWithInt:errorCode] forKey:@"code"];
    [posError setObject:errorMessage ? errorMessage : @"" forKey:@"message"];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];

    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

-(void)playSoundAlert{
    
    AudioServicesPlaySystemSound(soundId);
}
-(void) dealloc {
    AudioServicesDisposeSystemSoundID(soundId);
}

- (id)parseParameters:(CDVInvokedUrlCommand*)command {
    NSArray *data = [command arguments];
    if (data.count == 1) {
        return [data objectAtIndex:0];
    }
    return Nil;
}

@end
