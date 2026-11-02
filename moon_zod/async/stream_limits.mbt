///|
/// Bounds buffered input, measured in UTF-8 bytes before decoding.
///
/// SSE frames include all field/comment lines and their logical line endings.
/// Oversized input raises `StreamLimitExceeded`; the caller owns the reader.
pub(all) struct StreamReadLimits {
  max_line_bytes : Int32
  max_frame_bytes : Int32
}

///|
/// Default limits: 64 KiB per line and 1 MiB per SSE frame.
pub fn StreamReadLimits::default() -> StreamReadLimits {
  { max_line_bytes: 65536, max_frame_bytes: 1048576, }
}

///|
/// A line or SSE frame exceeded its configured buffering limit.
pub(all) suberror StreamLimitExceeded {
  LineTooLong(Int32)
  FrameTooLarge(Int32)
} derive(Debug)

///|
#deprecated
pub extend StreamLimitExceeded with @debug.Debug::{to_repr}

///|
fn StreamReadLimits::check(self : StreamReadLimits) -> Unit {
  if self.max_line_bytes <= 0 || self.max_frame_bytes <= 0 {
    abort("stream read limits must be positive")
  }
}
