int foo(int a) {
   a += 6;
   return a;
}

void lol(int a) {
    print(a);
	return;
}

void main(){
   int a;
   a = foo(4);
   lol(a);
   float b = foo(4)-5.2;
   print(b);
   return;
}
