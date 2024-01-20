# Xcluster ovl - test-template

Template for test program using `ovl/test` script-based testing.


## Run tests

```
log=/tmp/$USER/xcluster-test.log
./test-template test > $log
# Or;
xcadmin k8s_test test-template > $log
# Or with another CNI-plugin;
xcadmin k8s_test --cni=cilium test-template > $log
```

If you use a [private registry](../private-reg/) (and you really
should), then you must pre-load the CNI-plugin images;

```
images lreg_preload k8s-cni-calico
xcadmin k8s_test --cni=calico test-template > $log
```


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
