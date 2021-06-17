# Install tclx manually

```bash
sudo yum install tcl-devel tk-devel

git clone https://github.com/flightaware/tclx
cd tclx
./configure
make
sudo make install
sudo ln -s /usr/lib/tclx8.6/ /usr/share/tcl8.6/tclx8.6
```
