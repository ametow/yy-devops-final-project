### Запуск развёртывания 
(Примерное время: 25 минут, включая миграцию)

```shell
make deploy
```

### Очистка тестового стенда

```shell
make clean
```

### Описание процесса развёртывания HA (High Availability) стенда Bingo

Сначала я тщательно изучил техническое задание, прочитав его несколько раз. Затем я спланировал архитектуру сервисов и их взаимодействие. В ТЗ было указано необходимость запуска Bingo-сервиса на двух узлах для обеспечения отказоустойчивости, поэтому я выделил две виртуальные машины (ВМ) для этой цели. Поскольку Bingo-сервисы связываются с PostgreSQL, я выделил ещё одну ВМ для базы данных. Для распределения входящего трафика между двумя узлами потребовалась ещё одна ВМ с балансировщиком нагрузки.

![Архитектура Bingo](bingo.jpg "Архитектура")

Я начал с запуска исполняемого файла локально на своём компьютере. Этот процесс, хотя и был загадочным, не составил особого труда благодаря знаниям, полученным на лекциях по DevOps. Инструменты как Strace и lsof оказались весьма полезными.

Сначала я хотел автоматизировать создание ВМ с помощью Terraform, но, не имея опыта работы с этим инструментом, я решил начать с ручного создания, ориентируясь на документацию для последующей автоматизации.

Использовал `Terraform` для развёртывания и `Ansible` для управления конфигурацией.

Я начал с базы данных, установив `Postgres` через apt. После миграции создал индексы для таблиц *sessions* и *customers*, чтобы ускорить обработку запросов и удовлетворить требования ТЗ.

Затем развернул ВМ для Bingo и запустил его там. Команда `bingo prepare_db` заняла около 20 минут на миграцию, а `bingo run_server` - 30 секунд на запуск. Чтобы бинарник работал в фоновом режиме и автоматически перезапускался при сбоях, я превратил его в сервис systemd, создав соответствующий файл "bingo.service" в директории "/etc/systemd/system" ([bingo.service](./bingo/bingo.service)). Хотя запуск бинарника и его соединение с БД казались простыми, бинарник иногда выдавал ошибку "We all gonna die" и отвечал на все запросы ошибкой. Чтобы обеспечить успешное прохождение тестов, я написал shell-скрипт ([monitor_bingo.sh](./bingo/monitor_bingo.sh)), который каждые 31 секунду отправлял GET-запрос и проверял HTTP-код ответа. Если код отличался от 200, скрипт перезапускал бинарник командой `systemctl restart bingo`. Я также сделал этот скрипт системным сервисом, по аналогии с предыдущим ([monitor_bingo.service](./bingo/monitor_bingo.service)). Выбор интервала в 31 секунду был обусловлен временем запуска бинарника в 30 секунд, чтобы избежать ложного срабатывания скрипта во время его старта.

Для балансировки нагрузки я выбрал `HAProxy`, благодаря его удобному синтаксису и возможности эффективно контролировать upstream-серверы. Несмотря на отсутствие поддержки кэширования "из коробки", я добавил сервис `Varnish` для кэширования ответов в соответствии с ТЗ. Создал самоподписанный сертификат и включил поддержку **http3**, собрав `HAProxy` из исходников с нужными параметрами. `HAProxy` поддерживает экспорт метрик в формате Prometheus, что упростило визуализацию данных через `unified-agent` от `YandexCloud`.

После того как стенд заработал, я автоматизировал все ранее выполненные вручную процессы с помощью Terraform и Ansible.