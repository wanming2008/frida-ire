#include "Session.hpp"

#include "Marshal.hpp"

using System::Windows::Threading::DispatcherPriority;

namespace Frida
{
  static void OnSessionClosed (FridaSession * session, gpointer user_data);
  static void OnScriptMessage (FridaScript * script, const gchar * msg, gpointer user_data);

  Session::Session (void * handle, Dispatcher ^ dispatcher)
    : handle (FRIDA_SESSION (handle)),
      dispatcher (dispatcher)
  {
    selfHandle = new msclr::gcroot<Session ^> (this);

    onClosedHandler = gcnew EventHandler (this, &Session::OnClosed);

    g_signal_connect (handle, "closed", G_CALLBACK (OnSessionClosed), selfHandle);
  }

  Session::~Session ()
  {
    g_object_unref (handle);
    handle = NULL;

    delete selfHandle;
    selfHandle = NULL;
  }

  void
  Session::Close ()
  {
    frida_session_close (handle);
  }

  Script ^
  Session::CreateScript (String ^ source)
  {
    FridaScript * scriptHandle;

    GError * error = NULL;
    gchar * sourceUtf8 = Marshal::ClrStringToUTF8CString (source);
    scriptHandle = frida_session_create_script (handle, sourceUtf8, &error);
    g_free (sourceUtf8);
    Marshal::ThrowGErrorIfSet (&error);

    return gcnew Script (scriptHandle, dispatcher);
  }

  void
  Session::OnClosed (Object ^ sender, EventArgs ^ e)
  {
    if (dispatcher->CheckAccess ())
      Closed (sender, e);
    else
      dispatcher->BeginInvoke (DispatcherPriority::Normal, onClosedHandler, sender, e);
  }

  static void
  OnSessionClosed (FridaSession * session, gpointer user_data)
  {
    (void) session;

    msclr::gcroot<Session ^> * wrapper = static_cast<msclr::gcroot<Session ^> *> (user_data);
    (*wrapper)->OnClosed (*wrapper, EventArgs::Empty);
  }

  Script::Script (FridaScript * handle, Dispatcher ^ dispatcher)
    : handle (handle),
      dispatcher (dispatcher)
  {
    selfHandle = new msclr::gcroot<Script ^> (this);

    onMessageHandler = gcnew ScriptMessageHandler (this, &Script::OnMessage);

    g_signal_connect (handle, "message", G_CALLBACK (OnScriptMessage), selfHandle);
  }

  Script::~Script ()
  {
    g_object_unref (handle);
    handle = NULL;

    delete selfHandle;
    selfHandle = NULL;
  }

  void
  Script::Load ()
  {
    GError * error = NULL;
    frida_script_load (handle, &error);
    Marshal::ThrowGErrorIfSet (&error);
  }

  void
  Script::Unload ()
  {
    GError * error = NULL;
    frida_script_unload (handle, &error);
    Marshal::ThrowGErrorIfSet (&error);
  }

  void
  Script::PostMessage (String ^ msg)
  {
    GError * error = NULL;
    gchar * msgUtf8 = Marshal::ClrStringToUTF8CString (msg);
    frida_script_post_message (handle, msgUtf8, &error);
    g_free (msgUtf8);
    Marshal::ThrowGErrorIfSet (&error);
  }

  void
  Script::OnMessage (Object ^ sender, ScriptMessageEventArgs ^ e)
  {
    if (dispatcher->CheckAccess ())
      Message (sender, e);
    else
      dispatcher->BeginInvoke (DispatcherPriority::Normal, onMessageHandler, sender, e);
  }

  static void
  OnScriptMessage (FridaScript * script, const gchar * msg, gpointer user_data)
  {
    (void) script;

    msclr::gcroot<Script ^> * wrapper = static_cast<msclr::gcroot<Script ^> *> (user_data);
    ScriptMessageEventArgs ^ e = gcnew ScriptMessageEventArgs (
        Marshal::UTF8CStringToClrString (msg));
   (*wrapper)->OnMessage (*wrapper, e);
  }
}