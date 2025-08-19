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

int isMusicAppRunning(void) {
    MusicApplication* music = getMusicApp();
    return [music isRunning] ? 1 : 0;
}

MusicPlayerState getPlayerState(void) {
    if (!isMusicAppRunning()) {
        return MusicPlayerStateStopped;
    }

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

double getPlayerPosition(void) {
    if (!isMusicAppRunning()) {
        return 0.0;
    }

    MusicApplication* music = getMusicApp();
    return [music playerPosition];
}

DetailedTrackInfo getCurrentTrackInfo(void) {
    DetailedTrackInfo info = {0};

    if (!isMusicAppRunning()) {
        return info;
    }

    MusicApplication* music = getMusicApp();
    MusicTrack* currentTrack = [music currentTrack];

    if (!currentTrack) {
        return info;
    }

    info.isValid = 1;

    // Basic track information
    NSString* title = [currentTrack name];
    if (title) info.title = strdup([title UTF8String]);

    NSString* artist = [currentTrack artist];
    if (artist) info.artist = strdup([artist UTF8String]);

    NSString* album = [currentTrack album];
    if (album) info.album = strdup([album UTF8String]);

    NSString* albumArtist = [currentTrack albumArtist];
    if (albumArtist) info.albumArtist = strdup([albumArtist UTF8String]);

    NSString* composer = [currentTrack composer];
    if (composer) info.composer = strdup([composer UTF8String]);

    NSString* genre = [currentTrack genre];
    if (genre) info.genre = strdup([genre UTF8String]);

    // Numeric information
    info.year = [currentTrack year];
    info.trackNumber = [currentTrack trackNumber];
    info.trackCount = [currentTrack trackCount];
    info.discNumber = [currentTrack discNumber];
    info.discCount = [currentTrack discCount];
    info.duration = [currentTrack duration];
    info.playedCount = [currentTrack playedCount];
    info.rating = [currentTrack rating];

    // Date information
    NSDate* playedDate = [currentTrack playedDate];
    if (playedDate) {
        info.playedDate = [playedDate timeIntervalSince1970];
    }

    // Player state
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