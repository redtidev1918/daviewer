#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

bool SetStringValue(HKEY key, const wchar_t* name,
                    const std::wstring& value) {
  const auto bytes = static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  return ::RegSetValueExW(key, name, 0, REG_SZ,
                          reinterpret_cast<const BYTE*>(value.c_str()),
                          bytes) == ERROR_SUCCESS;
}

// The release is distributed as an unpackaged ZIP, so Windows has no package
// manifest that can own the OAuth callback protocol. Register it for the
// current user on every normal launch; this needs no administrator access and
// also repairs the executable path when the folder is moved after extraction.
bool RegisterOAuthProtocol() {
  wchar_t executable[32768];
  constexpr DWORD executable_capacity =
      static_cast<DWORD>(sizeof(executable) / sizeof(executable[0]));
  const DWORD length = ::GetModuleFileNameW(
      nullptr, executable, executable_capacity);
  if (length == 0 || length >= executable_capacity - 1) {
    return false;
  }

  HKEY protocol_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\dakit", 0,
                        nullptr, 0, KEY_WRITE, nullptr, &protocol_key,
                        nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const bool protocol_ok =
      SetStringValue(protocol_key, nullptr, L"URL:DAViewer OAuth callback") &&
      SetStringValue(protocol_key, L"URL Protocol", L"");
  ::RegCloseKey(protocol_key);

  HKEY command_key = nullptr;
  if (::RegCreateKeyExW(
          HKEY_CURRENT_USER,
          L"Software\\Classes\\dakit\\shell\\open\\command", 0, nullptr, 0,
          KEY_WRITE, nullptr, &command_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const std::wstring command =
      L"\"" + std::wstring(executable, length) + L"\" \"%1\"";
  const bool command_ok = SetStringValue(command_key, nullptr, command);
  ::RegCloseKey(command_key);
  return protocol_ok && command_ok;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // OAuth callbacks launch the registered executable again. Forward the URI
  // to the already-running Flutter instance instead of creating a second app.
  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }

  RegisterOAuthProtocol();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"DA Viewer", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
