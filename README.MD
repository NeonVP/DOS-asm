# Assembly DOS Tasks (TASM)

This repository was created to study assembly in DOS

|      Имя       |       Расположение      |        Описание         |
| -------------- | ----------------------- | ----------------------- |
| Framed message | [vram-asm](./vram-asm/) | Вывод сообщение в рамке |

## Examples of work

### String in frame

Usage: file.com [BG] [TXT] [Fill] [Flag] [7Chars if Flag=1] [Message]

![Example 1](img/example1.png)
*Пример 1. Вызов программы без передачи параметров: ```file.com```*

![Example 2](img/example2.png)
*Пример 2. Запуск с параметрами: ```file.com 1F 4E ♥ 0 Hello, World!```*

![Example 3](img/example3.png)
*Пример 3. Запуск с параметрами: ```file.com 1D 3F . 0 MEOW```*

![Example 4](img/example4.png)
*Пример 3. Запуск с параметрами: ```file.com 1F 0F . 1 #I#-#I# Hello, World!```*
