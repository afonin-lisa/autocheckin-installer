# AutoCheckin Installer

Автоматическая установка AutoCheckin SaaS — системы управления посуточной арендой.

## Быстрый старт

```bash
curl -sSL https://install.afonin-lisa.ru | sudo bash
```

## Требования

- Ubuntu 22.04 / 24.04
- 2+ vCPU, 4+ GB RAM, 20+ GB disk
- Публичный IP
- LICENSE_KEY (получаете при регистрации)

## Обновление

```bash
sudo /opt/autocheckin-installer/install.sh --update
```

## Recovery

```bash
sudo /opt/autocheckin-installer/recovery/rollback.sh        # откат версии
sudo /opt/autocheckin-installer/recovery/reinstall.sh       # переустановка
sudo /opt/autocheckin-installer/recovery/restore-from-backup.sh  # восстановление БД
```

## Структура

```
autocheckin-installer/
├── install.sh          # Главная точка входа
├── lib/
│   ├── colors.sh       # Цвета и хелперы вывода
│   ├── prompts.sh      # Интерактивный ввод
│   ├── validators.sh   # Валидация данных
│   ├── health.sh       # Проверка здоровья сервисов
│   └── logs.sh         # Логирование
├── wizards/            # Пошаговые мастера установки
├── templates/          # Шаблоны конфигурации
└── recovery/           # Скрипты восстановления
```

## Логи

```bash
tail -f /var/log/autocheckin/install.log
```
