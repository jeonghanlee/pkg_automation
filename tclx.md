sudo yum install tcl-devel tk-devel

git clone https://github.com/flightaware/tclx
cd tclx
./configure
make
make test
sudo make install
