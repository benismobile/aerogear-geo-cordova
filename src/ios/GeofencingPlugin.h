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

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import <AudioToolbox/AudioServices.h>
enum CDVLocationStatus {
    PERMISSIONDENIED = 1,
    GEOFENCINGPERMISSIONDENIED = 2
};

@interface GeofencingPlugin : CDVPlugin<CLLocationManagerDelegate>
{
    SystemSoundID soundId;
}
@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, copy) NSString *callbackId;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong) NSMutableSet *monitoringRegions;
@property (nonatomic, strong) NSMutableSet *insideRegions;

- (void)register:(CDVInvokedUrlCommand*)command;
- (void)addRegion:(CDVInvokedUrlCommand *)command;
- (void)removeRegion:(CDVInvokedUrlCommand *)command;
- (void)getWatchedRegionIds:(CDVInvokedUrlCommand *)command;
- (void)playSoundAlert;
@end
