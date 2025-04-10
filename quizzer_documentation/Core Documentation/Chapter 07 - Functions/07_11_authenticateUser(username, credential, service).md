This function will be called by the submit button and by the social media login buttons

Will take the credentials provided and send them to the associated service using a switch statement

```
var service = 'OPEN';
switch (command) {
  case 'twitter':
    return_code = http call;
  case 'google':
    return_code = http call;
  case 'facebook':
    return_code = http call;
  case 'gitlab':
    return_code = http call;
  case 'github':
    return_code = http call;
  default:
    return_code = http call;
}
```