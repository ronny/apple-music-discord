// MusicScriptingBridge.h
#ifndef MUSIC_SCRIPTING_BRIDGE_H
#define MUSIC_SCRIPTING_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Player state enum matching Zig PlayerState
typedef enum {
    MusicPlayerStateStopped = 0,
    MusicPlayerStatePlaying = 1,
    MusicPlayerStatePaused = 2,
    MusicPlayerStateFastForwarding = 3,
    MusicPlayerStateRewinding = 4
} MusicPlayerState;

// Structure to hold detailed track information
typedef struct {
    int isValid;
    char *title;
    char *artist;
    char *album;
    char *albumArtist;
    char *composer;
    char *genre;
    char *persistentID;  // Apple Music persistent ID for deep linking
    int databaseID;      // Database ID from iTunes/Music.app
    int year;
    int trackNumber;
    int trackCount;
    int discNumber;
    int discCount;
    double duration;
    int playedCount;
    int rating;
    double playedDate;
    int isPlaying;
    int isPaused;
} DetailedTrackInfo;

// Function declarations
int isMusicAppRunning(void);
MusicPlayerState getPlayerState(void);
double getPlayerPosition(void);
DetailedTrackInfo getCurrentTrackInfo(void);
void freeTrackInfo(DetailedTrackInfo* info);
void clearTrackCache(void);

#ifdef __cplusplus
}
#endif

#endif // MUSIC_SCRIPTING_BRIDGE_H