//
//  AppDelegate.m
//  Now Playing in iTunes
//
//  Created by Zachary Whitten on 3/19/15.
//  Copyright (c) 2015 Zachary Whitten. All rights reserved.
//

#import "AppDelegate.h"



@interface AppDelegate ()


@end

@implementation AppDelegate{
    NSString *nowPlayingFilepath;
    NSString *saveDataFilepath;
    NSString *exemptArtistFilepath;
    NSString *exemptArtist;
    BOOL isdelayed;
    int delayInputFails;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    //Get filepath of where application data is to be saved. If application folder does not exist, the appliction will create it. This would happen if it was the first time the app was launched
    NSFileManager *fileManager = [[NSFileManager alloc]init];
    NSURL *filepath = [[NSURL alloc]init];
    filepath = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSString *stringFilepath = [filepath path];
    NSString *savedDataFilepath = [NSString stringWithFormat:@"%@/Now Playing in iTunes",stringFilepath];
    if ([fileManager fileExistsAtPath:savedDataFilepath] == false) {
        [fileManager createDirectoryAtPath:savedDataFilepath withIntermediateDirectories:NO attributes:nil error:nil];
    }
    saveDataFilepath = [savedDataFilepath stringByAppendingPathComponent:@"/NowPlayingLocation.txt"];
    exemptArtistFilepath = [savedDataFilepath stringByAppendingPathComponent:@"/ExemptArtist.txt"];
    
    //unarchive saved data for the now playing filepath
    nowPlayingFilepath = [NSKeyedUnarchiver unarchiveObjectWithFile:saveDataFilepath];
    if (nowPlayingFilepath == nil) {
        //The default filepath is the location where Nicecast saves its now playing. If that filepath isn't found, then the user must select a filepath manually. If they don't do that, the applicaiton terminates.
        NSFileManager *fileManager = [[NSFileManager alloc]init];
        NSURL *filepath = [[NSURL alloc]init];
        filepath = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSString *stringFilepath = [filepath path];
        NSString *savedDataFilepath = [NSString stringWithFormat:@"%@/Nicecast/NowPlaying.txt",stringFilepath];
        if ([fileManager fileExistsAtPath:savedDataFilepath] == false) {
            bool didSelectFilepath = [self changeFilepath];
            if (didSelectFilepath == false) {
                [[NSApplication sharedApplication] terminate:nil];
            }
        }
        else{
            nowPlayingFilepath = savedDataFilepath;
            [NSKeyedArchiver archiveRootObject:nowPlayingFilepath toFile:saveDataFilepath];
        }

    }
    //unarchive saved data for the exempt artist filepath
    exemptArtist = [NSKeyedUnarchiver unarchiveObjectWithFile:exemptArtistFilepath];
    if (exemptArtist == nil) {
        exemptArtist = @"WCNU Radio";
        [NSKeyedArchiver archiveRootObject:exemptArtist toFile:exemptArtistFilepath];
    }
    
    //Create and init NSTimer
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(masterTimeControler: ) userInfo:nil repeats:YES];
    
    //Initalize isDelayed and set it to false
    isdelayed = false;
    
    //Inialize user input fails and set it to zero as the user can not have failed before the app has even finished stating
    delayInputFails = 0;
    
    //Creates the menu bar
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Change Exempt Artist" action:@selector(changeExemptArtist) keyEquivalent:@""];
    [menu addItemWithTitle:@"Change Output Filepath" action:@selector(changeFilepath) keyEquivalent:@""];
    [menu addItemWithTitle:@"Temporarily Disable" action:@selector(setDelay) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];

     //Creating the drop down window
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.menu = menu;
    NSImage *iconImage = [NSImage imageNamed:@"NowPlayingBlack.png"];
    _statusItem.image = iconImage;
    _statusItem.highlightMode = YES;
    
    //Initalize our ApplescriptBridge object
    _myBridge = [[ApplescriptBridge alloc]init];
    
}

-(void)masterTimeControler:(NSTimer*)timer{
    if (isdelayed == false) {
        if ([_myBridge isiTunesPlaying] == true) {
            BOOL didGetTrackInfo = [_myBridge getInfoFromiTunes_ExemptArtist:exemptArtist NowPlayingFilepath:nowPlayingFilepath];
            if (didGetTrackInfo == true) {
                NSImage *iconImage = [NSImage imageNamed:@"NowPlayingGreen.png"];
                _statusItem.image = iconImage;
            }
            else{
                NSImage *iconImage = [NSImage imageNamed:@"NowPlayingRed.png"];
                _statusItem.image = iconImage;
            }
        }
        else{
            NSImage *iconImage = [NSImage imageNamed:@"NowPlayingBlack.png"];
            _statusItem.image = iconImage;
        }
    }
    else{
        NSImage *iconImage = [NSImage imageNamed:@"NowPlayingRed.png"];
        _statusItem.image = iconImage;
    }
}

-(BOOL)changeExemptArtist{
    NSApplication *myApp = [NSApplication sharedApplication];
    [myApp activateIgnoringOtherApps:YES];
    exemptArtist = [self textInputAlert];
    [NSKeyedArchiver archiveRootObject:exemptArtist toFile:exemptArtistFilepath];
    return true;
}

- (NSString *)textInputAlert{
    NSAlert *alert = [[NSAlert alloc]init];
    [alert setMessageText:@"Set Exempt Artist"];
    [alert setInformativeText:@"Type artist which will application will ignore"];
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 295, 24)];
    //[input setStringValue:defaultValue];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertFirstButtonReturn) {
        [input validateEditing];
        return [input stringValue];
    }
    else {
        return @"";
    }

}

- (BOOL)changeFilepath{
    //create load panel, make panel only accept files with correct file extenction, get file path selevted by user, load the data
    NSApplication *myApp = [NSApplication sharedApplication];
    [myApp activateIgnoringOtherApps:YES];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSArray *fileTypes = [[NSArray alloc] initWithObjects:@"txt", nil];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowedFileTypes:fileTypes];
    if ( [openPanel runModal] == NSModalResponseOK ) {
        NSURL *pathURL = [openPanel URL];
        NSString *pathString = [pathURL path];
        return [self processFile:pathString];
    }
    else{
        return false;
    }
}

- (BOOL)processFile:(NSString *)file{
    //Check if the file is a now playing file
    BOOL isNowPlaying = true;
    NSArray *filepathParts = [file componentsSeparatedByString:@"/"];
    if (![[filepathParts lastObject] isEqualToString:@"NowPlaying.txt"]){
        NSAlert *confirmOpenSchedule = [[NSAlert alloc]init];
        [confirmOpenSchedule messageText];
        [confirmOpenSchedule setMessageText:@"Are you sure you want to select a non \"NowPlaying.txt\" file?"];
        [confirmOpenSchedule addButtonWithTitle:@"Cancel"];
        [confirmOpenSchedule addButtonWithTitle:@"Ok"];
        NSInteger returnValue = [confirmOpenSchedule runModal];
        if (returnValue == 1000) {
            isNowPlaying = false;
        }
    }
    if (isNowPlaying == true) {
        nowPlayingFilepath = file;
        [NSKeyedArchiver archiveRootObject:nowPlayingFilepath toFile:saveDataFilepath];
        return true;
    }
    else{
        return false;
    }
  }

-(void)changeIcon{
    NSImage *iconImage = [NSImage imageNamed:@"NowPlayingGreen.png"];
    _statusItem.image = iconImage;
}

-(BOOL)setDelay{
    //Generate and run input window
    NSApplication *myApp = [NSApplication sharedApplication];
    [myApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc]init];
    [alert setMessageText:@"Enter amount of time to disable for"];
    [alert setInformativeText:@"Please enter a number of minutes to delay"];
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 295, 24)];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    
    //Validating input. If an error in the input is found, the function is called again recurcivially. In theory this could cause a break but ... global counter and crash. Testing required. Function could also be cleaned up and reduced in size.
    if (button == NSAlertFirstButtonReturn) {
        [input validateEditing];
        NSInteger delay = [input integerValue];
        NSString *stringDelay = [input stringValue];
        if (delay == 0 && ![stringDelay isEqualToString:@"0"]) {
            NSAlert *alert = [[NSAlert alloc]init];
            [alert setMessageText:@"Must enter a valid input"];
            [alert setInformativeText:@"Input must be a number"];
            [alert addButtonWithTitle:@"Ok"];
            [alert runModal];
            if (delayInputFails >= 10) {
                delayInputFails = 0;
                NSAlert *alert = [[NSAlert alloc]init];
                [alert setMessageText:@"Please just enter a valid input"];
                [alert addButtonWithTitle:@"Ok"];
                [alert runModal];
                return false;

            }
            else{
                delayInputFails = delayInputFails + 1;
                [self setDelay];
            }
           

        }
        else if (delay < 1) {
            NSAlert *alert = [[NSAlert alloc]init];
            [alert setMessageText:@"Must enter a number greater than zero"];
            [alert addButtonWithTitle:@"Ok"];
            [alert runModal];
            if (delayInputFails >= 10) {
                delayInputFails = 0;
                NSAlert *alert = [[NSAlert alloc]init];
                [alert setMessageText:@"Please just enter a valid input"];
                [alert addButtonWithTitle:@"Ok"];
                [alert runModal];
                return false;
                
            }
            else{
                delayInputFails = delayInputFails + 1;
                [self setDelay];
            }
        }
        else if (delay > 30) {
            NSAlert *alert = [[NSAlert alloc]init];
            [alert setMessageText:@"Must enter a number less than or equal to 30"];
            [alert addButtonWithTitle:@"Ok"];
            [alert runModal];
            if (delayInputFails >= 10) {
                delayInputFails = 0;
                NSAlert *alert = [[NSAlert alloc]init];
                [alert setMessageText:@"Please just enter a valid input"];
                [alert addButtonWithTitle:@"Ok"];
                [alert runModal];
                return false;
                
            }
            else{
                delayInputFails = delayInputFails + 1;
                [self setDelay];
            }
        }
        else{
            isdelayed = true;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (delay * 60) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                isdelayed = false;
            });
        }
        
    }
    else {
        return false;
    }
    return true;
}

@end