namespace Zed.Agent {
	public class AgentServer : Object, AgentSession {
		public string listen_address {
			get;
			construct;
		}

		private MainLoop main_loop = new MainLoop ();
		private DBusServer server;
		private bool closing = false;
		private Gee.ArrayList<DBusConnection> active_connections = new Gee.ArrayList<DBusConnection> ();
		private Gee.ArrayList<DBusConnection> dead_connections = new Gee.ArrayList<DBusConnection> ();
		private Gee.HashMap<DBusConnection, uint> registration_id_by_connection = new Gee.HashMap<DBusConnection, uint> ();
		private ScriptEngine script_engine = new ScriptEngine ();

		public AgentServer (string listen_address) {
			Object (listen_address: listen_address);
		}

		construct {
			script_engine.message_from_script.connect ((script_id, message, data) => this.message_from_script (script_id, message, data));
		}

		public async void close () throws IOError {
			if (closing)
				throw new IOError.FAILED ("close already in progress");
			closing = true;

			server.stop ();
			server = null;

			if (script_engine != null) {
				script_engine.shutdown ();
				script_engine = null;
			}

			Timeout.add (100, () => {
				close_connections_and_schedule_shutdown ();
				return false;
			});
		}

		private async void close_connections_and_schedule_shutdown () {
			yield reap_dead_connections ();
			yield close_active_connections ();

			Timeout.add (100, () => {
				main_loop.quit ();
				return false;
			});
		}

		public async AgentScriptId create_script (string source) throws IOError {
			var instance = script_engine.create_script (source);
			return instance.sid;
		}

		public async void destroy_script (AgentScriptId sid) throws IOError {
			script_engine.destroy_script (sid);
		}

		public async void load_script (AgentScriptId sid) throws IOError {
			script_engine.load_script (sid);
		}

		public async void post_message_to_script (AgentScriptId sid, string message) throws IOError {
			script_engine.post_message_to_script (sid, message);
		}

		public void run () throws Error {
			server = new DBusServer.sync (listen_address, DBusServerFlags.AUTHENTICATION_ALLOW_ANONYMOUS, DBus.generate_guid ());
			server.new_connection.connect ((connection) => {
				connection.closed.connect (on_connection_closed);

				try {
					Zed.AgentSession session = this;
					var registration_id = connection.register_object (Zed.ObjectPath.AGENT_SESSION, session);
					registration_id_by_connection[connection] = registration_id;
				} catch (IOError e) {
					printerr ("failed to register object: %s\n", e.message);
					close ();
					return false;
				}

				active_connections.add (connection);
				return true;
			});

			server.start ();

			main_loop = new MainLoop ();
			main_loop.run ();
		}

		private void on_connection_closed (DBusConnection connection, bool remote_peer_vanished, GLib.Error? error) {
			bool closed_by_us = (!remote_peer_vanished && error == null);
			if (closed_by_us)
				return;

			unregister (connection);

			active_connections.remove (connection);
			dead_connections.add (connection);
			if (active_connections.is_empty)
				close ();
			else
				reap_dead_connections ();
		}

		private async void close_active_connections () {
			while (active_connections.size != 0) {
				var connections = active_connections.to_array ();
				active_connections.clear ();
				foreach (var connection in connections) {
					unregister (connection);

					try {
						yield connection.close ();
					} catch (Error e) {
					}
				}
			}
		}

		private async void reap_dead_connections () {
			while (dead_connections.size != 0) {
				var connections = dead_connections.to_array ();
				dead_connections.clear ();
				foreach (var connection in connections) {
					try {
						yield connection.close ();
					} catch (Error e) {
					}
				}
			}
		}

		private async void unregister (DBusConnection connection) {
			uint registration_id;
			if (registration_id_by_connection.unset (connection, out registration_id))
				connection.unregister_object (registration_id);
		}
	}

	public class AutoIgnorer : Object, Gum.InvocationListener {
		protected Gum.Interceptor interceptor;

		public AutoIgnorer (Gum.Interceptor interceptor) {
			this.interceptor = interceptor;
		}

		public void enable () {
			interceptor.attach_listener ((void *) Thread.create_full, this);
		}

		public void disable () {
			interceptor.detach_listener (this);
		}

		private void on_enter (Gum.InvocationContext context) {
			intercept_thread_creation (context);
		}

		private void on_leave (Gum.InvocationContext context) {
		}

		private extern void intercept_thread_creation (Gum.InvocationContext context);
	}

	public void main (string listen_address) {
		Environment.init ();
		run_server_listening_on (listen_address);
		Environment.deinit ();
	}

	private void run_server_listening_on (string listen_address) {
		var interceptor = Gum.Interceptor.obtain ();
		interceptor.ignore_current_thread ();

		var ignorer = new AutoIgnorer (interceptor);
		ignorer.enable ();

		var server = new AgentServer (listen_address);

		try {
			server.run ();
		} catch (Error e) {
			printerr ("error: %s\n", e.message);
		}

		ignorer.disable ();
		interceptor.unignore_current_thread ();
	}

	namespace Environment {
		public extern void init ();
		public extern void deinit ();
	}

}
