//
//  SUAutomaticUpdateDriver.m
//  Sparkle
//
//  Created by Andy Matuschak on 5/6/08.
//  Copyright 2008 Andy Matuschak. All rights reserved.
//

#import "SUAutomaticUpdateDriver.h"

#import "SUAutomaticUpdateAlert.h"
#import "SUHost.h"
#import "SUConstants.h"

@implementation SUAutomaticUpdateDriver

- (void)showUpdateAlert
{
	isInterruptible = NO;
	alert = [[SUAutomaticUpdateAlert alloc] initWithAppcastItem:updateItem host:host delegate:self];
	
	// If the app is a menubar app or the like, we need to focus it first and alter the
	// update prompt to behave like a normal window. Otherwise if the window were hidden
	// there may be no way for the application to be activated to make it visible again.
	if ([host isBackgroundApplication])
	{
		[[alert window] setHidesOnDeactivate:NO];
		[NSApp activateIgnoringOtherApps:YES];
	}		
	
	if ([NSApp isActive])
		[[alert window] makeKeyAndOrderFront:self];
	else
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:NSApp];	
}

- (void)unarchiverDidFinish:(SUUnarchiver *)ua
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];

    // Sudden termination is available on 10.6+
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    if ([processInfo respondsToSelector:@selector(disableSuddenTermination)]) {
        [processInfo disableSuddenTermination];
    }

    willUpdateOnTermination = YES;
    
    // apply the update
    [self stopUpdatingOnTermination];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *installPath = [host installationPath];
    // Check if we need admin password to install the app
    BOOL needAuthorization = ([fm isWritableFileAtPath:installPath] == NO);
        
    if (needAuthorization) {
        [self showUpdateAlert];
    } else {
        [self installWithToolAndRelaunch:YES displayingUserInterface:NO];
    }
}

- (void)stopUpdatingOnTermination
{
    if (willUpdateOnTermination)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(enableSuddenTermination)]) {
            [processInfo enableSuddenTermination];
        }
        willUpdateOnTermination = NO;

        if ([[updater delegate] respondsToSelector:@selector(updater:didCancelInstallUpdateOnQuit:)])
            [[updater delegate] updater:updater didCancelInstallUpdateOnQuit:updateItem];
    }
}

- (void)dealloc
{
    [self stopUpdatingOnTermination];
    [alert release];
    [super dealloc];
}

- (void)abortUpdate
{
    [self stopUpdatingOnTermination];
    [super abortUpdate];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	[[alert window] makeKeyAndOrderFront:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"NSApplicationDidBecomeActiveNotification" object:NSApp];
}

- (void)automaticUpdateAlert:(SUAutomaticUpdateAlert *)aua finishedWithChoice:(SUAutomaticInstallationChoice)choice;
{
	switch (choice)
	{
		case SUInstallNowChoice:
            [self stopUpdatingOnTermination];
			[self installWithToolAndRelaunch:YES];
			break;
			
		case SUInstallLaterChoice:
			// We're already waiting on quit, just indicate that we're idle.
			isInterruptible = YES;
			break;

		case SUDoNotInstallChoice:
			[host setObject:[updateItem versionString] forUserDefaultsKey:SUSkippedVersionKey];
			[self abortUpdate];
			break;
	}
}

- (void)installWithToolAndRelaunch:(BOOL)relaunch displayingUserInterface:(BOOL)showUI
{
    if (relaunch)
        [self stopUpdatingOnTermination];

    showErrors = YES;
    [super installWithToolAndRelaunch:relaunch displayingUserInterface:showUI];
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	[self installWithToolAndRelaunch:NO];
}

- (void)abortUpdateWithError:(NSError *)error
{
	if (showErrors)
		[super abortUpdateWithError:error];
	else
		[self abortUpdate];
}

@end
