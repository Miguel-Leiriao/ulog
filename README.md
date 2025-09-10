# ulog

[![Buy Me a Coffee](https://img.shields.io/badge/☕-Buy%20me%20a%20coffee-orange)](https://www.buymeacoffee.com/MiguelLeiriao)

uLog is a **compact, uniform, and tamper-evident logging system**.  
Designed for small applications, IoT devices, and microservices where memory is limited but **log quality and trust** are critical.  

## Features
- Compact binary log format (saves memory & storage)
- Standardized structure (`severity, channel, code, payload, ts_delta`)
- Hash-linked blocks with CRC → tamper-evident
- Human-readable export (`#-123-yellow-SNS-14:55:37.100 id=7 ms=850`)
- Free & open-source. Always.  

## Status
This project starts with a **Ruby gem**.  
Future branches will include:
- Rust (for Linux systems)
- C (low-level embedded use)

## Support
The project is free and open-source.  
If you find it useful, consider buying me a coffee:

## Contributing
Contributions, issues and feature requests are welcome!  

[Buy me a coffee](https://www.buymeacoffee.com/MiguelLeiriao)
