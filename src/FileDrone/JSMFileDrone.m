//
// Copyright © 2013 Daniel Farrelly
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// *	Redistributions of source code must retain the above copyright notice, this list
//		of conditions and the following disclaimer.
// *	Redistributions in binary form must reproduce the above copyright notice, this
//		list of conditions and the following disclaimer in the documentation and/or
//		other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "JSMFileDrone.h"
#import "JSMFileMonitor.h"
#import <CommonCrypto/CommonDigest.h>

NSString *const JSMFileDroneFilesChanged = @"JSMFileDroneFilesChanged";

NSString *const JSMFileDroneDefaultName = @"JSMDefaultFileDrone";

@interface JSMFileDrone ()

@property (strong, nonatomic) NSString *encodedIdentifier;

@property (nonatomic) BOOL allowUpdates;

@property (nonatomic) BOOL refreshAgain;

@property (strong, nonatomic) NSDictionary *modificationDates;

@property (strong, nonatomic) NSMutableDictionary *monitors;

@property (strong, nonatomic) NSMutableArray *refreshCompletions;

@end

@implementation JSMFileDrone

@synthesize fileURLs = _fileURLs;

#pragma mark - Creating a FileDrone

+ (instancetype)defaultFileDrone {
	static JSMFileDrone *_sharedDocuments = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSURL *documentsURL = [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        _sharedDocuments = [JSMFileDrone fileDroneForDirectoryURL:documentsURL];
        _sharedDocuments.name = JSMFileDroneDefaultName;
	});
	return _sharedDocuments;
}

+ (instancetype)fileDroneForDirectoryURL:(NSURL *)directoryURL {
    return [[JSMFileDrone alloc] initWithDirectoryURL:directoryURL];
}

- (instancetype)initWithDirectoryURL:(NSURL *)directoryURL {
    if( ( self = [super init] ) ) {

        self.directoryURL = directoryURL;

        // Enable updates by default
        _allowUpdates = YES;

        // Enable recursive mode by default
        _recursive = YES;

        // Place to store monitors
        _monitors = [NSMutableDictionary dictionary];

        // Get the stored list of modification dates
        if( [NSFileManager.defaultManager fileExistsAtPath:[self modificationDatesURL].path] ) {
            _modificationDates = [[NSDictionary alloc] initWithContentsOfURL:[self modificationDatesURL]];
        }

    }
    return self;
}

- (void)dealloc {
    [self stopSurveillance];
}

#pragma mark - Identifying your FileDrone

- (BOOL)isNamed:(NSString *)name {
    return [self.name isEqualToString:name];
}

#pragma mark - Directory

- (void)setDirectoryURL:(NSURL *)directoryURL {
    // Check that this path exists
    BOOL isDirectory;
    if( ! [NSFileManager.defaultManager fileExistsAtPath:directoryURL.path isDirectory:&isDirectory] || ! isDirectory ) {
        NSString *reason = [NSString stringWithFormat:@"%@ is not a valid watchable directory. Please provide a NSURL representing a valid directory.", directoryURL.path];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
    }
    // If we're surveilling, stop for now
    BOOL isSurveilling = self.isSurveilling;
    if( isSurveilling ) {
        [self stopSurveillance];
    }
    // Set the directoryURL
    _directoryURL = directoryURL;
    // Store an encoded identifier
    const char *utf8 = _directoryURL.absoluteString.UTF8String;
    unsigned char md5Buffer[16];
    CC_MD5( utf8, (int)strlen(utf8), md5Buffer );
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x",md5Buffer[i]];
    _encodedIdentifier = [output copy];
    // Start surveilling again
    if( isSurveilling ) {
        [self startSurveillance];
    }
}

#pragma mark - Returning URLs

- (NSArray *)fileURLs {
    // If we've gotten file URLs, returned those.
    if( _fileURLs != nil ) {
        return _fileURLs;
    }
    // Fetch the file URLs
    NSMutableArray *mutableURLs = [NSMutableArray array];
    [self enumerateDirectoryContentsWithBlock:^(NSURL *url) {
        [mutableURLs addObject:url];
    }];
    return mutableURLs.copy;
}

#pragma mark - Manual surveillance

// This method is deprecated
- (void)refresh {
    [self automatedRefresh];
}

- (void)automatedRefresh {
    // If we're refreshing already, postpone for later
    _refreshAgain = ( ! _allowUpdates );
    // Do a refresh
    [self refreshWithCompletion:^(NSArray *addedURLs,NSArray *changedURLs,NSArray *removedURLs) {
        // If we're surveilling automatically
        if( ! self.isSurveilling ) {
            return;
        }
        // Make the userinfo dictionary from the updates we recieved
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if( addedURLs.count > 0 ) {
            [userInfo setObject:addedURLs forKey:kFileDroneNotificationAddedURLs];
        }
        if( changedURLs.count > 0 ) {
            [userInfo setObject:changedURLs forKey:kFileDroneNotificationChangedURLs];
        }
        if( removedURLs.count > 0 ) {
            [userInfo setObject:removedURLs forKey:kFileDroneNotificationRemovedURLs];
        }
        // Only bother with the notification if there are changes
        [userInfo setObject:_directoryURL forKey:kFileDroneNotificationDirectoryURL];
        [[NSNotificationCenter defaultCenter] postNotificationName:JSMFileDroneFilesChanged object:self userInfo:userInfo.copy];
        // Refresh again so we don't miss anything.
        if( _refreshAgain ) {
            _refreshAgain = NO;
            [self performSelector:@selector(automatedRefresh) withObject:nil afterDelay:1];
        }
    }];
}

- (void)refreshWithCompletion:(JSMFileDroneRefreshCompletion)completion {
    // Let's make sure we're allowing updates at the moment
    if( ! _allowUpdates ) {
        // Add this completion if it's not nil
        if( completion != nil ) {
            [_refreshCompletions addObject:completion];
        }
        // Don't go any further
        return;
    }
    // Stop updates for a minute
    _allowUpdates = NO;
    // Add this completion if it's not nil
    if( completion != nil ) {
        // Prep the completions array
        if( _refreshCompletions == nil ) {
            _refreshCompletions = [NSMutableArray array];
        }
        // Add the block
        [_refreshCompletions addObject:completion];
    }
    // Go to a background queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // We're just going to breathe a moment
        //[NSThread sleepForTimeInterval:0.5];
        // We're going to fetch a list of files, and a list of new ones
        NSMutableArray *fileURLs = [NSMutableArray array];
        NSMutableArray *addedFileURLs = [NSMutableArray array];
        NSMutableArray *changedFileURLs = [NSMutableArray array];
        NSMutableDictionary *modificationDates = [NSMutableDictionary dictionary];
        // Go over the directory contents
        [self enumerateDirectoryContentsWithBlock:^(NSURL *url) {
            // Make a URL relative to the watched directory
            NSString *relativePath = [url.standardizedURL.absoluteString stringByReplacingOccurrencesOfString:self.directoryURL.standardizedURL.absoluteString withString:@""];
            NSURL *relativeURL = [NSURL URLWithString:relativePath relativeToURL:self.directoryURL.URLByStandardizingPath];
            // Add to the fileURLs array
            [fileURLs addObject:relativeURL];
            // Get the modification date and add to the dictionary
            NSDate *modificationDate;
            [url getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:NULL];
            [modificationDates setObject:modificationDate forKey:relativeURL.absoluteString];
            // If the url isn't in our existing list, it goes in the addedFileURLs too
            if( ! [_fileURLs containsObject:relativeURL] ) {
                [addedFileURLs addObject:relativeURL];
                [changedFileURLs addObject:relativeURL];
            }
            // If the url isn't in our existing list, it goes in the addedFileURLs too
            else if( [modificationDate timeIntervalSinceDate:(NSDate *)[_modificationDates objectForKey:relativeURL.absoluteString]] ) {
                [changedFileURLs addObject:relativeURL];
            }
        }];
        // Now we determine what files were removed
        NSArray *removedFileURLs = [NSArray array];
        if( ! [_fileURLs isEqualToArray:fileURLs] ) {
            NSMutableSet *oldSet = [NSMutableSet setWithArray:_fileURLs];
            NSMutableSet *newSet = [NSMutableSet setWithArray:fileURLs];
            [oldSet minusSet:newSet];
            removedFileURLs = [oldSet allObjects];
        }
        // Update the list of files
        if( ! [_fileURLs isEqualToArray:fileURLs.copy] ) {
            _fileURLs = fileURLs.copy;
        }
        // Update the list of modification dates
        if( ! [_modificationDates isEqualToDictionary:modificationDates.copy] ) {
            _modificationDates = modificationDates.copy;
            // Store them as a file too
            [_modificationDates writeToURL:[self modificationDatesURL] atomically:YES];
        }
        // Update the list of added files
        if( ! [_addedFileURLs isEqualToArray:addedFileURLs.copy] ) {
            _addedFileURLs = addedFileURLs.copy;
        }
        // Update the list of files that have been modified
        if( ! [_changedFileURLs isEqualToArray:changedFileURLs.copy] ) {
            _changedFileURLs = changedFileURLs.copy;
        }
        // Update the list of removed files
        if( ! [_removedFileURLs isEqualToArray:removedFileURLs] ) {
            _removedFileURLs = removedFileURLs;
        }
        // Go to the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            // Call the completion blocks
            [_refreshCompletions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                JSMFileDroneRefreshCompletion completion = (JSMFileDroneRefreshCompletion)obj;
                completion( _addedFileURLs, _changedFileURLs, _removedFileURLs );
            }];
            // Empty the completion array
            _refreshCompletions = nil;
        });
        // Restart updates
        _allowUpdates = YES;
    });
}

- (NSURL *)modificationDatesURL {
    NSString *file = [NSString stringWithFormat:@"JSMFileDrone.%@.modifiedtimes",_encodedIdentifier];
    return [[[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:file];
}

#pragma mark - Automatic surveillance

- (BOOL)isSurveilling {
    return ( _monitors.count > 0 );
}

- (void)startSurveillance {
    // We're already surveilling
    if( self.isSurveilling ) {
        return;
    }
    // Add notifications for starting and stopping when the app transitions to and from the background
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enableUpdates) name:@"UIApplicationWillEnterForegroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enableUpdates) name:@"UIApplicationDidBecomeActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disableUpdates) name:@"UIApplicationWillResignActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disableUpdates) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopSurveillance) name:@"UIApplicationWillTerminateNotification" object:nil];
    // Start surveilling
    NSDirectoryEnumerator *dirEnumerator = [self directoryEnumeratorIncludingPropertiesForKeys:@[ NSURLIsDirectoryKey ]];
    [self addMonitorForURL:_directoryURL];
    for( NSURL *url in dirEnumerator ) {
        NSNumber *isDirectory;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        if( [isDirectory boolValue] == YES ) {
            [self addMonitorForURL:url];
        }
    }
    // Do a manual refresh
    [self automatedRefresh];
}

- (void)stopSurveillance {
    // We're not surveilling
    if( ! self.isSurveilling ) {
        return;
    }
    // Remove notifications for starting and stopping when the app transitions to and from the background
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationWillEnterForegroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationDidBecomeActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationWillResignActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationWillTerminateNotification" object:nil];
    // Stop the current surveillance
    [self removeMonitorForURL:_directoryURL];
    [_monitors enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        JSMFileMonitor *monitor = (JSMFileMonitor *)obj;
        [self removeMonitorForURL:monitor.url];
    }];
}

- (void)enableUpdates {
    // We're not surveilling anyway
    if( ! self.isSurveilling ) {
        return;
    }
    // we're already allowing updates
    if( _allowUpdates ) {
        return;
    }
    // Enable updates
    _allowUpdates = YES;
}

- (void)disableUpdates {
    // We're not surveilling anyway
    if( ! self.isSurveilling ) {
        return;
    }
    // We're not allowing updates
    if( ! _allowUpdates ) {
        return;
    }
    // Disable updates
    _allowUpdates = NO;
}

#pragma mark - Utilities

- (NSDirectoryEnumerator *)directoryEnumeratorIncludingPropertiesForKeys:(NSArray *)keys {
    return [NSFileManager.defaultManager enumeratorAtURL:_directoryURL includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) {
        return YES;
    }];
}

- (void)enumerateDirectoryContentsWithBlock:(void(^)(NSURL *url))block {
    // Fetch an enumerator so we can go through the directory contents
    NSDirectoryEnumerator *dirEnumerator = [self directoryEnumeratorIncludingPropertiesForKeys:@[ NSURLNameKey, NSURLIsDirectoryKey, NSURLTypeIdentifierKey, NSURLContentModificationDateKey ]];
    // Enumerate the dirEnumerator results, each value is stored in allURLs
    for( NSURL *url in dirEnumerator ) {
        // If it's a directory, we do nothing
        NSNumber *isDirectory;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        if( [isDirectory boolValue] == YES ) {
            if( _recursive ) {
                continue;
            }
            else {
                [dirEnumerator skipDescendents];
            }
        }
        // Match against the file name regular expression
        if( _fileNameRegex != nil ) {
            NSString *fileName;
            [url getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
            if( [_fileNameRegex numberOfMatchesInString:fileName options:0 range:NSMakeRange( 0, fileName.length )] <= 0 ) {
                continue;
            }
        }
        // Match against the type identifier regular expression
        if( _typeIdentifierRegex != nil ) {
            NSString *typeIdentifier;
            [url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:NULL];
            if( [_typeIdentifierRegex numberOfMatchesInString:typeIdentifier options:0 range:NSMakeRange( 0, typeIdentifier.length )] <= 0 ) {
                continue;
            }
        }
        // Run the block
        block( url );
    }
}

- (void)addMonitorForURL:(NSURL *)url {
    // We already have one
    if( [_monitors objectForKey:url.absoluteString] ) {
        return;
    }
    // Create the monitor
    JSMFileMonitor *monitor = [JSMFileMonitor monitorWithURL:url];
    [monitor observeChangesWithTarget:self andSelector:@selector(refresh)];
    // Try to start it
    if( ! [monitor start] ) {
        return;
    }
    // Add to the dictionary
    [_monitors setObject:monitor forKey:url.absoluteString];
}

- (void)removeMonitorForURL:(NSURL *)url {
    // We don't have one
    JSMFileMonitor *monitor;
    if( ( monitor = [_monitors objectForKey:url.absoluteString] ) == nil ) {
        return;
    }
    // First shut it down
    [monitor stop];
    // Then remove it
    [_monitors removeObjectForKey:url.absoluteString];
}

@end
