import gleam/option.{type Option}

pub type MessageAttrs {
  MessageAttrs(id: Int, from_id: Int, reply_to_message_id: Option(Int))
}
