# Xcluster ovl - test-template

Template for test program using `ovl/test` script-based testing.

This tamplate builds clusters for ipv4 and ipv6 and performs start-up
tests.

## Usage

Copy the test scripts in this ovl to your new ovl, rename and sed;

```
testtmpl=$($XCLUSTER ovld test-template)
cdo some-ovl
myovl=$(basename $PWD)
mkdir -p default/bin
cp $testtmpl/test-template.sh $myovl.sh
cp $testtmpl/default/bin/test-template_test default/bin/${myovl}_test
sed -i -e "s,test-template,$myovl," $myovl.sh
sed -i -e "s,test-template,$myovl," default/bin/${myovl}_test
# Test
./$myovl.sh test
```

Add your own tests.
