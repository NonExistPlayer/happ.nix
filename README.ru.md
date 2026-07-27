<div align="center">

[English](README.md) | **Русский**

</div>

> Данный репозиторий является форком и "flake адаптацией" [happ-nixos](https://github.com/MrShitFox/happ-nixos).

# `happ.nix`

> Запуск прокси-клиента [Happ](https://github.com/Happ-proxy/happ-desktop) на NixOS — с нормальной упаковкой и рабочим HWID.

Happ распространяется в виде готового Debian-пакета, который рассчитывает на
обычную FHS-раскладку и доступный для записи `/opt/happ` — ничего из этого на
NixOS нет. Этот модуль переупаковывает клиент для Nix store и настраивает всё
необходимое для его чистой работы.

Flake в себя включает:

- **Нативная упаковка под Nix**
- **Рабочий HWID**
- **Готовность к TUN-режиму**
- **Быстрые пересборки**

## Установка

> [!TIP]
> Данный flake имеет output `apps`, что позволяет запускать Happ через `nix run`.
>
> Вы можете попробовать этот flake до его установки!
> ```bash
> nix run github:NonExistPlayer/happ.nix
> ```

Добавляйте в ваш flake конфигурации новый `input`:
```nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    happ = {
      url = "github:NonExistPlayer/happ.nix";
      inputs.nixpkgs.follows = "nixpkgs"; # необязательно
    };
  };
```

А далее в `nixosConfigurations`, добавляете `nixosModules` из этого flake'а:

```nix
  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.pc =
       nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         modules = [
           ./hosts/pc
           inputs.happ.nixosModules.default
         ];
       };
  };
```

Теперь просто включите Happ:

```nix
{ ... }:
{
  services.happ.enable = true;
}
```

> [!WARNING]
> Не устанавливайте пакет на прямую, вроде этого:
> ```nix
> { pkgs, ... }:
> {
>   environment.systemPackages =
>     let
>       happ = inputs.happ.packages.default;
>     in
>     [
>       happ
>     ];
> }
> ```
> Иначе вы потеряете все основные важные возможности flake'а, включая фикс HWID.

## Опции

| Опция | По умолчанию | Описание |
| --- | --- | --- |
| `services.happ.enable` | `false` | Включить клиент Happ и демон `happd`. |
| `services.happ.package` | собирается из `happ.nix` | Переопределить пакет Happ. |
| `services.happ.forceXwayland` | `false` | Запускать Happ через XWayland вместо встроенных Qt6 Wayland-плагинов. См. [Краш на Wayland / Hyprland](#краш-на-wayland--hyprland) ниже. |
| `services.happ.forceSoftwareRendering` | `false` | Принудительно включить программный рендеринг для Qt Quick UI Happ. См. [Краш на Wayland / Hyprland](#краш-на-wayland--hyprland) ниже. |
| `services.happ.tunInterface` | `"tun0"` | TUN-устройство, которому доверяет firewall. |

## Фикс HWID

Happ получает свой hardware id из `machineUniqueId()` в Qt, который на Linux
читает файл `/var/lib/dbus/machine-id`. NixOS по умолчанию использует
**dbus-broker**, и — в отличие от классического dbus-daemon — он не создаёт
этот файл, поэтому id возвращается пустым, а в клиенте отображается пустой
HWID. Модуль линкует его на настоящий machine id:

```nix
systemd.tmpfiles.rules = [ "L+ /var/lib/dbus/machine-id - - - - /etc/machine-id" ];
```

## Краш на Wayland / Hyprland

Встроенные Qt6 Wayland-плагины Happ могут молча вызывать краш клиента на
композиторах на базе wlroots (Hyprland, Sway, ...) — несовпадение ABI или
отсутствующая зависимость относительно того, что зашил вендор. Если Happ не
запускается на одном из них, установите:

```nix
services.happ.forceXwayland = true;
```

Это убирает встроенные Wayland-плагины из пакета и закрепляет Qt на XCB
(XWayland), что обходит краш. По умолчанию выключено, так как не подтверждено,
затрагивает ли краш композиторы с более зрелой поддержкой Qt6 Wayland (GNOME, KDE).

Если после этого интерфейс всё равно отображается некорректно (или не
отображается вовсе) — это отдельная проблема на уровне GPU/драйвера — также
установите:

```nix
services.happ.forceSoftwareRendering = true;
```

Это не зависит от `forceXwayland`: опция принудительно включает программный
рендеринг Qt Quick независимо от того, какой платформенный бэкенд (Wayland
или XCB) активен.

## Примечания

- Протоколы: VLESS, VMess, Trojan, Shadowsocks через TUN. Hysteria2 не поддерживается.
- Happ имеет unfree/distributable лицензию. Вам потребуется включить `allowUnfree`
  или разрешить другими способами.
- Неофициальный модуль сообщества — не аффилирован с проектом Happ.

### Компромиссы безопасности

- `happd` работает **от root без sandboxing в systemd** (нет `ProtectSystem`,
  `PrivateTmp` и т.д.) — усиление изоляции ломает bind mount machine-id,
  необходимый TUN-режиму (см. фикс HWID выше).
- `networking.firewall.checkReversePath` установлен в `"loose"`
  **на уровне всей системы** (не только для TUN-интерфейса) — это требуется
  из-за асимметричной маршрутизации, которую создаёт TUN-режим.

Оба решения намеренные и необходимы для работы TUN-режима: не включайте
sandboxing для `happd` и не ужесточайте `checkReversePath` без повторного
тестирования подключения через TUN.

## Лицензия

[GPL-3.0](LICENSE) — см. файл LICENSE.
