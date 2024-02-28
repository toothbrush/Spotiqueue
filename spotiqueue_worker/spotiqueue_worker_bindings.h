#ifndef spotiqueue_worker_h
#define spotiqueue_worker_h

/* WARNING: This file is auto-generated by cbindgen. Don't modify. */

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum StatusUpdate {
  EndOfTrack,
  Paused,
  Playing,
  Stopped,
  TimeToPreloadNextTrack,
} StatusUpdate;

typedef enum InitializationResult_Tag {
  InitOkay,
  InitBadCredentials,
  InitNotPremium,
  InitProblem,
} InitializationResult_Tag;

typedef struct InitProblem_Body {
  const char *description;
} InitProblem_Body;

typedef struct InitializationResult {
  InitializationResult_Tag tag;
  union {
    InitProblem_Body init_problem;
  };
} InitializationResult;

void set_callback(void (*callback)(enum StatusUpdate status,
                                   uint32_t position_ms,
                                   uint32_t duration_ms));

void spotiqueue_initialize_worker(void);

struct InitializationResult spotiqueue_login_worker(const char *username_raw,
                                                    const char *password_raw);

bool spotiqueue_pause_playback(void);

void spotiqueue_unpause_playback(void);

bool spotiqueue_preload_track(const char *spotify_uri_raw);

bool spotiqueue_play_track(const char *spotify_uri_raw, bool start, uint32_t position_ms);

#endif /* spotiqueue_worker_h */
