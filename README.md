# osynca

"Набор программных модулей" (далее, для краткости, просто "программа") OSYNCA предназначен для синхронизации файлов на двух компьютерах с их переносом на сменном носителе (далее - "флешке"). Программа должна работать под любой Windows, для её работы также нужен архиватор [7z](http://www.7-zip.org/).

# Файлы в дистрибутиве

* osynca.exe - исполняемый файл для создания списков синхронизируемых файлов;
* osynca.ini - примерный файл конфигурации программы;
* sync.ini - примерный файл синхронизации;
* init.bat - bat-файл для первичной настройки программы;
* put.bat0 - тепмплейт bat-файла put.bat для рутинной отправки файлов с данного компьютера на удалённый;
* get.bat0 - тепмплейт bat-файла get.bat для рутинного получения файлов на данный компьютер с удалённого;
* put.ico - иконка для файла put.bat;
* get.ico - иконка для файла get.bat.

В процессе первичной настройки будут сгенерированы ещё два файла:

* put.bat - пакетный файл для переноса файлов на удалённый компьютер;
* get.bat - пакетный файл для получения файлов с удалённого компьютера.

# Схема и особенности работы

Программа создаёт и поддерживает для каждого из компьютеров список синхронизируемых файлов (далее - "список синхронизации") с датами их последней модификации. При синхронизации программа переносит с одного компьютера на другой новые файлы и файлы, имеющие более свежие даты модификации, а также удаляет на втором компьютере файлы, удалённые на первом. Удалённые файлы, а также старые версии модифицированных, сохраняются в бэкапах, что даёт возможность при необходимости откатить изменения.

Программа не сможет разобраться в ситуации, при которой файлы будут *одновременно* изменяться на обоих компьютерах.

В силу специфики средств реализации синхронизируемые каталоги на обоих компьютерах должны находиться  на одноименных логических дисках. Если каталог с файлами находится не на том диске, который нужен (скажем, на c:, а нужен d:), и файловая система - NTFS, то проблему можно решить, создав [точку соединения (junction)](https://ru.wikipedia.org/wiki/%D0%A2%D0%BE%D1%87%D0%BA%D0%B0_%D1%81%D0%BE%D0%B5%D0%B4%D0%B8%D0%BD%D0%B5%D0%BD%D0%B8%D1%8F_NTFS) на требуемом диске командой вида `mklink /J d:\JUNCTED_DIR c:\DIR`.

Программа не умеет создавать новые пустые и удалять старые опустевшие каталоги. Для решения этой проблемы можно использовать костыль, описанные ниже (см. remove_empty_dirs.bat).

# Первичная настройка

- Убедиться, что в системе установлен архиватор 7z.
- Скопировать файлы из каталога binary в рабочий каталог первого компьютера (например, D:\OSYNCA\\).
- В файле osynca.ini задать следующие параметры (в квадратных скобках здесь и далее - значения в приведённом в качестве примера файле):
  - DIRECTION - направление синхронизации (для первого компьютера должно быть 12) [12];
  - SDIR - "каталог синхронизации" для хранения списков синхронизации на флешке [Z:\OSYNCA\\SYNC\\];
- Можно (но не обязательно) поменять в том же файле osynca.ini следующие параметры:
  - EDLISTNAME - имя bat-файла для удаления пустых каталогов [remove_empty_dirs.bat];
  - EDPREFIX - команда для удаления пустых каталогов [rd /q].
- Переместить файл sync.ini из рабочего каталога в каталог синхронизации %SDIR% (на флешке).
- Задать в нём следующие параметры:
  - COMPUTER1 - имя первого компьютера [HOME];
  - COMPUTER2 - имя второго компьютера [WORK];
  - VOLUME - имя диска, на котором находятся синхронизируемые файлы [D:]
  - DIR0, DIR1, ..., DIR99 - каталоги для синхронизации [D:\DIR0\\, D:\DIR1\\].
- Можно (но не обязательно) поменять в том же файле sync.ini следующие параметры:
  - DTIME - максимальная разность времён модификации файлов в секундах, при котором они считаются одинаковыми [3];
- Запустить init.bat на первом компьютере. В рабочем каталоге будут созданы каталог BACKUP, файлы put.bat и get.bat. В каталоге %SDIR% (на флешке) будет создан список файлов файлов %COMPUTER1%.fil.
- Скопировать файлы osynca.exe, osynca.ini, put.bat0, get.bat0 в рабочий каталог второго компьютера.
- Поменять в файле osynca.ini значение переменной DIRECTION на 21.
- При необходимости поменять в нём же значение логического диска в параметре SDIR (чтобы он указывал на флешку).
- Запустить init.bat на втором компьютере. В рабочем каталоге будут созданы каталог BACKUP, файлы put.bat и get.bat. В каталоге %SDIR% будет создан список файлов %COMPUTER2%.fil.
- Можно удалить в рабочих каталогов обоих компьютеров файлы init.bat, put.bat0 и get.bat0.

# Рутинная процедура синхроницации

Перенос файлов с первого(второго) компьютера на второй(первый):

- Запустить put.bat на первом(втором) компьютере
- Перенести флешку на второй(первый) компьютер
- Запустить get.bat на втором(первом) компьютере

# Пустые каталоги

Как уже было сказано, пустые каталоги, удалённые на одном компьютере, на другом автоматически не удаляются, а пустые каталоги, созданные на одном компьютере, на другом не создаются. Для удаления ВСЕХ пустых каталогов из списка синхронизации предназначен автоматически генерируемый файл (по умолчанию он называется remove_empty_dirs.bat), который можно периодически запускать (или игнорировать, если вас не волнует наличие на двух компьютерах деревьев каталогов с несинхронизированными пустыми "листьями"). Если вы не хотите удаления каких-то пустых каталогов и/или их корректной синхронизации - создавайте в них, например, файлы-плейсхолдер нулевой длины.

# Параметры командной строки

Программа osynca.exe понимает следующие параметры командной строки:

- <имя файла> - имя файла инициализации (вместо osynca.ini по умолчанию);
- ключ /i - инициализация параметров при первичной настройке;
- ключ /f - построение списка синхронизации (\*.fil) для данного компьютера без создания списков для архиватора (\*.lst).

Они могут понадобиться вам при нестандартной настройке bat-файлов.
