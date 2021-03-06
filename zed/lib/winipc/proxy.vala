using Gee;

namespace WinIpc {
	public class ServerProxy : Proxy {
		public string address {
			get;
			construct;
		}

		public ServerProxy (string? address = null) {
			Object (address: address);
		}

		construct {
			if (address == null)
				address = generate_address ();
			pipe = create_named_pipe (address);
		}

		~ServerProxy () {
			close ();
		}

		public async void establish (uint timeout_msec=0) throws ProxyError {
			try {
				var operation = new PipeOperation (pipe);
				var result = connect_named_pipe (pipe, operation);
				yield complete_pipe_operation (result, operation, timeout_msec);
			} catch (IOError connect_error) {
				throw new ProxyError.IO_ERROR (connect_error.message);
			}

			process_messages ();
		}

		public override void close () {
			if (pipe != null) {
				destroy_named_pipe (pipe);
				pipe = null;
			}

			base.close ();
		}

		private string generate_address () {
			var builder = new StringBuilder ();

			builder.append ("zed-");
			for (uint i = 0; i != 16; i++) {
				builder.append_printf ("%02x", Random.int_range (0, 255));
			}

			return builder.str;
		}

		private extern static void * create_named_pipe (string name);
		private extern static void destroy_named_pipe (void * pipe);
		private extern static IOResult connect_named_pipe (void * pipe, PipeOperation op) throws IOError;
	}

	public class ClientProxy : Proxy {
		public string server_address {
			get;
			construct;
		}

		public ClientProxy (string server_address) {
			Object (server_address: server_address);
		}

		~ClientProxy () {
			close ();
		}

		public async void establish () throws ProxyError {
			try {
				pipe = open_pipe (server_address);
			} catch (IOError open_error) {
				var not_found_error = new IOError.NOT_FOUND ("");
				if (open_error.code == not_found_error.code) {
					throw new ProxyError.SERVER_NOT_FOUND (open_error.message);
				} else {
					throw new ProxyError.IO_ERROR (open_error.message);
				}
			}

			process_messages ();
		}

		public override void close () {
			if (pipe != null) {
				close_pipe (pipe);
				pipe = null;
			}

			base.close ();
		}

		private extern static void * open_pipe (string name) throws IOError;
		private extern static void close_pipe (void * pipe);
	}

	public abstract class Proxy : Object {
		public signal void closed (bool remote_peer_vanished);
		private bool has_been_closed = false;

		protected void * pipe;

		private uint last_handler_id = 1;
		private HashMap<string, QueryHandler> query_handlers = new HashMap<string, QueryHandler> ();
		private ArrayList<NotifyHandler> notify_handlers = new ArrayList<NotifyHandler> ();

		private uint32 last_request_id = 1;
		private ArrayList<PendingResponse> pending_responses = new ArrayList<PendingResponse> ();

		public virtual void close () {
			if (has_been_closed)
				return;
			has_been_closed = true;
			closed (false);
		}

		public uint register_query_sync_handler (string id, string? argument_type, owned QuerySyncHandler sync_handler) {
			assert (!query_handlers.has_key (id));
			var handler = new QueryHandler (id, new VariantTypeSpec (argument_type));
			handler.sync_handler = (owned) sync_handler;
			handler.tag = last_handler_id++;
			query_handlers[id] = handler;
			return handler.tag;
		}

		public uint register_query_async_handler (string id, string? argument_type, QueryAsyncHandler async_handler) {
			assert (!query_handlers.has_key (id));
			var handler = new QueryHandler (id, new VariantTypeSpec (argument_type));
			handler.async_handler = async_handler;
			handler.tag = last_handler_id++;
			query_handlers[id] = handler;
			return handler.tag;
		}

		public void unregister_query_handler (uint handler_tag) {
			string matching_id = null;

			foreach (var entry in query_handlers.entries) {
				if (entry.value.tag == handler_tag) {
					matching_id = entry.key;
					break;
				}
			}

			if (matching_id != null)
				query_handlers.unset (matching_id);
		}

		public uint add_notify_handler (string id, string? argument_type, owned NotifySyncHandler sync_handler) {
			var handler = new NotifyHandler (id, (owned) sync_handler, new VariantTypeSpec (argument_type));
			handler.tag = last_handler_id++;
			notify_handlers.add (handler);
			return handler.tag;
		}

		public void remove_notify_handler (uint handler_tag) {
			int matching_index = -1;

			int i = 0;
			foreach (var handler in notify_handlers) {
				if (handler.tag == handler_tag) {
					matching_index = i;
					break;
				}

				i++;
			}

			if (matching_index != -1)
				notify_handlers.remove_at (matching_index);
		}

		public async Variant query (string verb, Variant? argument = null, string? response_type = null) throws ProxyError {
			try {
				Variant? response_value;
				if (!yield send_request_and_receive_response (verb, argument, out response_value))
					throw new ProxyError.INVALID_QUERY ("No matching handler for " + verb);

				var response_spec = new VariantTypeSpec (response_type);
				if (!response_spec.has_same_type_as (response_value))
					throw new ProxyError.INVALID_RESPONSE ("Invalid response for " + verb);

				return response_value;
			} catch (IOError io_error) {
				throw new ProxyError.IO_ERROR (io_error.message);
			}
		}

		public async void emit (string id, Variant? argument = null) throws ProxyError {
			try {
				yield send_notify (id, argument);
			} catch (IOError io_error) {
				throw new ProxyError.IO_ERROR (io_error.message);
			}
		}

		protected async void process_messages () {
			try {
				while (pipe != null) {
					Variant msg;
					var msg_type = yield read_message (out msg);

					switch (msg_type) {
						case MessageType.REQUEST:
							process_request (msg);
							break;
						case MessageType.RESPONSE:
							process_response (msg);
							break;
						case MessageType.NOTIFY:
							process_notify (msg);
							break;
						default:
							break;
					}
				}
			} catch (IOError e) {
				if (!has_been_closed) {
					has_been_closed = true;
					closed (true);
				}
			}
		}

		private async void process_request (Variant msg) throws IOError {
			uint32 id;
			string verb;
			Variant argument_wrapper;
			msg.get (REQUEST_MESSAGE_TYPE_STRING, out id, out verb, out argument_wrapper);

			bool success = false;
			Variant response_value = null;
			var handler = query_handlers[verb];
			if (handler != null)
				success = yield handler.try_invoke (MaybeVariant.unwrap (argument_wrapper), out response_value);
			yield send_response (id, success, response_value);
		}

		private void process_response (Variant msg) {
			uint32 id;
			bool success;
			Variant response_value;
			msg.get (RESPONSE_MESSAGE_TYPE_STRING, out id, out success, out response_value);

			PendingResponse match = null;
			foreach (var p in pending_responses) {
				if (p.id == id) {
					p.complete (success, response_value);
					match = p;
					break;
				}
			}

			if (match != null)
				pending_responses.remove (match);
		}

		private void process_notify (Variant msg) {
			string id;
			Variant argument_wrapper, argument;
			msg.get (NOTIFY_MESSAGE_TYPE_STRING, out id, out argument_wrapper);
			argument = MaybeVariant.unwrap (argument_wrapper);

			foreach (var handler in notify_handlers) {
				if (handler.id == id)
					handler.try_invoke (argument);
			}
		}

		private async bool send_request_and_receive_response (string verb, Variant? argument, out Variant? response_value) throws IOError {
			var request_id = last_request_id++;
			var request_msg = new Variant (REQUEST_MESSAGE_TYPE_STRING, request_id, verb, MaybeVariant.wrap (argument));
			var pending = new PendingResponse (request_id, () => send_request_and_receive_response.callback ());
			pending_responses.add (pending);
			write_message (MessageType.REQUEST, request_msg);
			yield;

			response_value = MaybeVariant.unwrap (pending.response_value);
			return pending.success;
		}

		private async uint32 send_response (uint id, bool success, Variant? val) throws IOError {
			var msg = new Variant (RESPONSE_MESSAGE_TYPE_STRING, id, success, MaybeVariant.wrap (val));
			yield write_message (MessageType.RESPONSE, msg);
			return id;
		}

		private async void send_notify (string id, Variant? argument) throws IOError {
			var msg = new Variant (NOTIFY_MESSAGE_TYPE_STRING, id, MaybeVariant.wrap (argument));
			yield write_message (MessageType.NOTIFY, msg);
		}

		private async MessageType read_message (out Variant? v) throws IOError {
			v = null;

			uint8[] blob = yield _read_blob ();
			if (blob.length < MESSAGE_FIELD_ALIGNMENT + 1)
				return MessageType.INVALID;

			MessageType t = (MessageType) blob[0];
			unowned VariantType vt;
			switch (t) {
				case MessageType.REQUEST:
					vt = REQUEST_MESSAGE_TYPE;
					break;
				case MessageType.RESPONSE:
					vt = RESPONSE_MESSAGE_TYPE;
					break;
				case MessageType.NOTIFY:
					vt = NOTIFY_MESSAGE_TYPE;
					break;
				default:
					return MessageType.INVALID;
			}

			var body_blob = new MessageBodyBlob (blob, MESSAGE_FIELD_ALIGNMENT);
			unowned uint8[] body_data = body_blob.data; /* FIXME: workaround for Vala compiler bug */
			v = Variant.new_from_data (vt, body_data, false, body_blob);
			if (!v.is_normal_form ())
				return MessageType.INVALID;
			return t;
		}

		private async void write_message (MessageType t, Variant v) throws IOError {
			uint8[] blob = new uint8[MESSAGE_FIELD_ALIGNMENT + v.get_size ()];
			blob[0] = t;
			unowned uint8 * blob_start = blob;
			v.store (blob_start + MESSAGE_FIELD_ALIGNMENT);
			yield _write_blob (blob);
		}

		protected extern async uint8[] _read_blob () throws IOError;
		protected extern async void _write_blob (uint8[] blob) throws IOError;

		protected async void complete_pipe_operation (IOResult result, PipeOperation operation, uint timeout_msec) throws IOError {
			if (result == IOResult.SUCCESS)
				return;
			yield _wait_for_operation (operation, timeout_msec);
			operation.consume_result ();
		}

		protected extern async void _wait_for_operation (PipeOperation op, uint timeout_msec) throws IOError;

		private class QueryHandler {
			private string id;
			private VariantTypeSpec argument_spec;

			public QuerySyncHandler sync_handler;

			public QueryAsyncHandler async_handler;

			public uint tag {
				get;
				set;
			}

			public QueryHandler (string id, VariantTypeSpec argument_spec) {
				this.id = id;
				this.argument_spec = argument_spec;
			}

			public async bool try_invoke (Variant? argument, out Variant? response_value) {
				if (!argument_spec.has_same_type_as (argument)) {
					response_value = null;
					return false;
				}

				if (sync_handler != null)
					response_value = sync_handler (argument);
				else
					response_value = yield async_handler.handle_query (id, argument);

				return true;
			}
		}

		private class NotifyHandler {
			public string id {
				get;
				private set;
			}

			private NotifySyncHandler sync_handler;
			private VariantTypeSpec argument_spec;

			public uint tag {
				get;
				set;
			}

			public NotifyHandler (string id, owned NotifySyncHandler sync_handler, VariantTypeSpec argument_spec) {
				this.id = id;
				this.sync_handler = (owned) sync_handler;
				this.argument_spec = argument_spec;
			}

			public bool try_invoke (Variant? argument) {
				if (!argument_spec.has_same_type_as (argument))
					return false;

				sync_handler (argument);
				return true;
			}
		}

		private class VariantTypeSpec {
			private string? spec_string;
			private VariantType? exact_type;

			public VariantTypeSpec (string? spec_string) {
				this.spec_string = spec_string;
				if (spec_string != null && spec_string != "")
					this.exact_type = new VariantType (spec_string);
			}

			public bool has_same_type_as (Variant? v) {
				if (spec_string == null)
					return true;
				else if (spec_string == "")
					return v == null;
				else
					return v.get_type ().equal (exact_type);
			}
		}

		private class PendingResponse {
			public uint32 id {
				get;
				private set;
			}

			public delegate void CompletionHandler ();
			private CompletionHandler handler;

			public bool success {
				get;
				private set;
			}

			public Variant? response_value {
				get;
				private set;
			}

			public PendingResponse (uint32 id, owned CompletionHandler handler) {
				this.id = id;
				this.handler = (owned) handler;
			}

			public void complete (bool success, Variant? response_value) {
				this.success = success;
				this.response_value = response_value;
				handler ();
			}
		}

		private enum MessageType {
			INVALID,
			REQUEST,
			RESPONSE,
			NOTIFY
		}

		private const string REQUEST_MESSAGE_TYPE_STRING = "(usmv)";
		private VariantType REQUEST_MESSAGE_TYPE = new VariantType (REQUEST_MESSAGE_TYPE_STRING);

		private const string RESPONSE_MESSAGE_TYPE_STRING = "(ubmv)";
		private VariantType RESPONSE_MESSAGE_TYPE = new VariantType (RESPONSE_MESSAGE_TYPE_STRING);

		private const string NOTIFY_MESSAGE_TYPE_STRING = "(smv)";
		private VariantType NOTIFY_MESSAGE_TYPE = new VariantType (NOTIFY_MESSAGE_TYPE_STRING);

		private const uint8 MESSAGE_FIELD_ALIGNMENT = 8;

		private class MessageBodyBlob {
			public uint8[] data {
				get;
				private set;
			}

			public MessageBodyBlob (uint8[] data, size_t offset) {
				this.data = data[offset:data.length];
			}
		}
	}

	public errordomain ProxyError {
		SERVER_NOT_FOUND,
		INVALID_QUERY,
		INVALID_RESPONSE,
		IO_ERROR
	}

	public delegate Variant? QuerySyncHandler (Variant? argument);

	public interface QueryAsyncHandler : Object {
		public abstract async Variant? handle_query (string id, Variant? argument);
	}

	public delegate void NotifySyncHandler (Variant? argument);

	namespace WaitHandleSource {
		public static Source create (void * handle, bool owns_handle) {
			return wait_handle_source_new (handle, owns_handle);
		}
	}

	private extern Source wait_handle_source_new (void * handle, bool owns_handle);

	namespace MaybeVariant {
		private Variant wrap (Variant? val) {
			Variant variant = null;
			if (val != null)
				variant = new Variant.variant (val);
			return new Variant.maybe (VariantType.VARIANT, variant);
		}

		private Variant? unwrap (Variant wrapper) {
			Variant variant = wrapper.get_maybe ();
			if (variant == null)
				return null;
			return variant.get_variant ();
		}
	}

	protected class PipeOperation {
		public void * pipe_handle {
			get;
			set;
		}

		public void * wait_handle {
			get;
			set;
		}

		public void * overlapped {
			get;
			set;
		}

		public string function_name {
			get;
			set;
		}

		public void * buffer {
			get;
			set;
		}

		public void * user_data {
			get;
			set;
		}

		public PipeOperation (void * pipe) {
			pipe_handle = pipe;

			create_resources ();
		}

		~PipeOperation () {
			destroy_resources ();
		}

		public void * steal_buffer () {
			assert (this.buffer != null);
			void * result = this.buffer;
			this.buffer = null;
			return result;
		}

		public extern static PipeOperation from_overlapped (void * overlapped);

		public extern uint consume_result () throws IOError;

		private extern void create_resources ();
		private extern void destroy_resources ();
	}

	protected enum IOResult {
		INVALID,
		PENDING,
		SUCCESS
	}
}
