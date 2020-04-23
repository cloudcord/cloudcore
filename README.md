# cloudcore

Cloudcore is the backend service that makes CloudCord work. It contains a variety of features, including the part that actually hosts the bots, connects them to Discord, and adds a command and module interface with them. It then exposes itself to Redis Pub/Sub to receive events from the API and other services.

Feel free to make an issue or [contact me on Twitter](https://twitter.com/phineyes) if you have questions about how something works.

** Disclaimer: I was still learning Elixir while writing this, so some things don't use the best practices. **
