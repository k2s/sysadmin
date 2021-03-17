#!/bin/sh

echo "delta.chat:"
ssh page $@
echo
echo
echo "support.delta.chat:"
ssh sdcnew $@
echo
echo
echo "b1.delta.chat:"
ssh b1.delta.chat $@
echo
echo
echo "login.testrun.org:"
ssh login.testrun.org $@
echo
echo
echo "testrun.org:"
ssh testrun.org $@
echo
echo
echo "hq6.merlinux.eu:"
ssh hq6 $@
echo
echo
echo "dubby.org:"
ssh dubby.org $@
echo
echo
echo "lists.codespeak.net:"
ssh lists.codespeak.net $@

