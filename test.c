void main(){
	int a = 40.0;
    int b = 10;
    int c = 5;
    if (a == 40){
        print("a is equal to 40");
        if (b == 20) {
            print("b is equal to 20");
        }else if (b >= 10){
            print("b is not equal to 20");
            if(c == 5) {
                print("c is 5.");
            }else {
                print("c is not 5.");
            }
            if(c == 5) {
                print("c is 5.");
            }else {
                print("c is not 5.");
            }

        }
    }
    else if (a > 40){
        print("a is larger than 40");
    }
     else{
        print(666);
    }
    if(b == 10){
        print("b == 10");
    }
    else{
        print(123);
    }
    return;
}


