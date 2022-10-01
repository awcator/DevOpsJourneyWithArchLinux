## Mirror a entire webpage locally with all depended resource
```
wget  --no-clobber --page-requisites --html-extension --convert-links --restrict-file-names=windows --timestamping -e robots=off https://mywebsite.com
```
## copy to clipboard
```
echo hello|xclip -selection c -o


alias copy='xclip -selection c -o'
echo hello|copy
```
## paste from clipboard
```
xclip -selection c -o

alias paste="xclip -selection c -o"
paste|wc -l
```
