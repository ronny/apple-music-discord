// MusicScriptingBridge.m
#import <ScriptingBridge/ScriptingBridge.h>
#import "Music.h"  // Generated header
#include "MusicScriptingBridge.h"

static MusicApplication* getMusicApp(void) {
    static MusicApplication* musicApp = nil;
    if (!musicApp) {
        musicApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.Music"];
    }
    return musicApp;
}

// Cache for reducing ScriptingBridge memory leaks
static DetailedTrackInfo cachedTrackInfo = {0};
static double lastCacheTime = 0.0;
static const double CACHE_DURATION = 1.0; // Cache for 1 second

double getCurrentTime(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1000000000.0;
}

void clearTrackCache(void) {
    // Free cached track info
    free(cachedTrackInfo.title);
    free(cachedTrackInfo.artist);
    free(cachedTrackInfo.album);
    free(cachedTrackInfo.albumArtist);
    free(cachedTrackInfo.composer);
    free(cachedTrackInfo.genre);
    
    memset(&cachedTrackInfo, 0, sizeof(DetailedTrackInfo));
    lastCacheTime = 0.0;
}

int isMusicAppRunning(void) {
    @autoreleasepool {
        MusicApplication* music = getMusicApp();
        return [music isRunning] ? 1 : 0;
    }
}

MusicPlayerState getPlayerState(void) {
    if (!isMusicAppRunning()) {
        return MusicPlayerStateStopped;
    }

    @autoreleasepool {
        MusicApplication* music = getMusicApp();
        MusicEPlS playerState = [music playerState];

        switch (playerState) {
            case MusicEPlSPlaying:
                return MusicPlayerStatePlaying;
            case MusicEPlSPaused:
                return MusicPlayerStatePaused;
            case MusicEPlSFastForwarding:
                return MusicPlayerStateFastForwarding;
            case MusicEPlSRewinding:
                return MusicPlayerStateRewinding;
            case MusicEPlSStopped:
            default:
                return MusicPlayerStateStopped;
        }
    }
}

double getPlayerPosition(void) {
    if (!isMusicAppRunning()) {
        return 0.0;
    }

    @autoreleasepool {
        MusicApplication* music = getMusicApp();
        return [music playerPosition];
    }
}

DetailedTrackInfo getCurrentTrackInfo(void) {
    DetailedTrackInfo info = {0};

    if (!isMusicAppRunning()) {
        clearTrackCache();
        return info;
    }

    double currentTime = getCurrentTime();
    
    // Check if cache is still valid (only refresh every CACHE_DURATION seconds)
    if (cachedTrackInfo.isValid && (currentTime - lastCacheTime) < CACHE_DURATION) {
        // Return cached info - duplicate strings so caller can free them safely
        info = cachedTrackInfo;
        if (cachedTrackInfo.title) info.title = strdup(cachedTrackInfo.title);
        if (cachedTrackInfo.artist) info.artist = strdup(cachedTrackInfo.artist);
        if (cachedTrackInfo.album) info.album = strdup(cachedTrackInfo.album);
        if (cachedTrackInfo.albumArtist) info.albumArtist = strdup(cachedTrackInfo.albumArtist);
        if (cachedTrackInfo.composer) info.composer = strdup(cachedTrackInfo.composer);
        if (cachedTrackInfo.genre) info.genre = strdup(cachedTrackInfo.genre);
        
        // Update player state (this is cheap to get)
        MusicPlayerState state = getPlayerState();
        info.isPlaying = (state == MusicPlayerStatePlaying) ? 1 : 0;
        info.isPaused = (state == MusicPlayerStatePaused) ? 1 : 0;
        
        return info;
    }
    
    // Cache is expired or invalid - refresh from ScriptingBridge
    @autoreleasepool {
        MusicApplication* music = getMusicApp();
        MusicTrack* currentTrack = [music currentTrack];

        if (!currentTrack) {
            clearTrackCache();
            return info;
        }

        // Clear old cache
        clearTrackCache();
        lastCacheTime = currentTime;
            
        // Fetch and cache track info (this reduces ScriptingBridge calls from ~300/second to ~1/second)
        cachedTrackInfo.isValid = 1;
        
        NSString* title = [currentTrack name];
        if (title) cachedTrackInfo.title = strdup([title UTF8String]);

        NSString* artist = [currentTrack artist];
        if (artist) cachedTrackInfo.artist = strdup([artist UTF8String]);

        NSString* album = [currentTrack album];
        if (album) cachedTrackInfo.album = strdup([album UTF8String]);

        NSString* albumArtist = [currentTrack albumArtist];
        if (albumArtist) cachedTrackInfo.albumArtist = strdup([albumArtist UTF8String]);

        NSString* composer = [currentTrack composer];
        if (composer) cachedTrackInfo.composer = strdup([composer UTF8String]);

        NSString* genre = [currentTrack genre];
        if (genre) cachedTrackInfo.genre = strdup([genre UTF8String]);

        // Numeric information (these cause most leaks according to malloc_history)
        cachedTrackInfo.year = [currentTrack year];
        cachedTrackInfo.trackNumber = [currentTrack trackNumber];
        cachedTrackInfo.trackCount = [currentTrack trackCount];
        cachedTrackInfo.discNumber = [currentTrack discNumber];
        cachedTrackInfo.discCount = [currentTrack discCount];
        cachedTrackInfo.duration = [currentTrack duration];
        cachedTrackInfo.playedCount = [currentTrack playedCount];
        cachedTrackInfo.rating = [currentTrack rating];

        // Date information
        NSDate* playedDate = [currentTrack playedDate];
        if (playedDate) {
            cachedTrackInfo.playedDate = [playedDate timeIntervalSince1970];
        }
    } // autoreleasepool

    // Return a copy of cached track info
    info = cachedTrackInfo;
    
    // Duplicate strings so caller can free them safely
    if (cachedTrackInfo.title) info.title = strdup(cachedTrackInfo.title);
    if (cachedTrackInfo.artist) info.artist = strdup(cachedTrackInfo.artist);
    if (cachedTrackInfo.album) info.album = strdup(cachedTrackInfo.album);
    if (cachedTrackInfo.albumArtist) info.albumArtist = strdup(cachedTrackInfo.albumArtist);
    if (cachedTrackInfo.composer) info.composer = strdup(cachedTrackInfo.composer);
    if (cachedTrackInfo.genre) info.genre = strdup(cachedTrackInfo.genre);

    // Player state (always get current state)
    MusicPlayerState state = getPlayerState();
    info.isPlaying = (state == MusicPlayerStatePlaying) ? 1 : 0;
    info.isPaused = (state == MusicPlayerStatePaused) ? 1 : 0;

    return info;
}

void freeTrackInfo(DetailedTrackInfo* info) {
    if (info) {
        free(info->title);
        free(info->artist);
        free(info->album);
        free(info->albumArtist);
        free(info->composer);
        free(info->genre);

        info->title = NULL;
        info->artist = NULL;
        info->album = NULL;
        info->albumArtist = NULL;
        info->composer = NULL;
        info->genre = NULL;
        info->isValid = 0;
    }
}