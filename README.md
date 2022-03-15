# scafetch
Scafetch is a command-line tool to display information about your remote Git repositories in an aesthetic and visually pleasing way.

It currently supports fetching repository information from Github, Gitlab and Codeberg (Gitea).

# Usage
Use gyro to build:
```
gyro build -Drelease-safe
```
(You can optionally install it in a system or user wide directory for easier access, use the ``-p <prefix>`` flag for convenience)

Then, run the application:
```
./zig-out/bin/scafetch ziglang/zig
```
where ``ziglang/zig`` is taken as an example repository address, and the host defaults to Github

It is also possible to explicitly state the host service name

Host name | #1                     | #2                           | #3
----------|------------------------|------------------------------|---------------------------------
Github    | ``gh/<author>/<repo>`` | ``github/<author>/<repo>``   | ``github.com/<author>/<repo>``
Gitlab    | ``gl/<author>/<repo>`` | ``gitlab/<author>/<repo>``   | ``githlab.com/<author>/<repo>``
Codeberg  | ``cb/<author>/<repo>`` | ``codeberg/<author>/<repo>`` | ``codeberg.org/<author>/<repo>``

# License
scafetch is licensed under [MIT License](LICENSE)
