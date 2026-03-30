import gleam/erlang/process

/// Block wait for a shutdown signal (like Ctrl+C)
pub fn wait_for_shutdown_signal() -> Nil {
  process.trap_exits(True)

  let selector =
    process.new_selector()
    |> process.select_trapped_exits(fn(exit_msg) {
      // Return the exit message to indicate shutdown
      exit_msg
    })

  // Block forever until an exit signal is received
  let _exit = process.selector_receive_forever(selector)
  Nil
}
