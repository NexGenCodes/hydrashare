#ifndef HYDRA_MUSCLE_H
#define HYDRA_MUSCLE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Progress callback function type
// Args: bytes_transferred, total_bytes, user_data
typedef void (*progress_callback_t)(int64_t, int64_t, void *);

// Error codes
#define SUCCESS 0
#define ERROR_INVALID_FD -1
#define ERROR_TRANSFER_FAILED -2
#define ERROR_CANCELLED -3

// Transfer data using zero-copy techniques
// Returns: 0 on success, negative error code on failure
int32_t transfer_data(intptr_t source_fd, intptr_t dest_fd, int64_t file_size,
                      int32_t *cancel_flag, progress_callback_t callback,
                      void *user_data);

#ifdef __cplusplus
}
#endif

#endif // HYDRA_MUSCLE_H
