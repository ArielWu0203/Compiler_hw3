/*	Definition section */
%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

extern int yylineno;
extern int yylex();
extern void yyerror(char *s);
extern char *yytext; // Get current token from lex
extern char buf[256];

/* global variable */
int global_int = 0;
float global_float = 0;
bool global_bool = false;

/* varialble */

/* function */
char func_name[100] = "";
char func_type[100] = "";

/* 
    Operator :
        0 is start
        1 is integer
        2 is float
*/
int operator = 0;

FILE *file; // To generate .j file for Jasmin

void yyerror(char *s);

/* symbol table functions */
int lookup_symbol(char *name,bool variable,int scope,bool declare);//true;undeclare false: redclare
bool syntax_error = false;
int error = 0;
char ID_name[30] = "";
char param[30][50];
char param_t[30][50];
int param_i = 0;
bool func_error = false;

void create_symbol();
void insert_symbol(int index,char *name,char *kind,char *type,int scope_level,char *attr);
void dump_symbol(int scope);

/*symbol table*/
typedef struct symbol_entry{
    int index;
    char name[50];
    char kind[15];
    char type[10];
    int scope_level;
    char attr[500];
    struct symbol_entry *next;
    struct symbol_entry *prev;
    bool forward_func;
} Entry;

Entry *front,*rear;
void del_node(Entry *node);

int now_level = 0,now_index = 0;


/* ID symbol */
Entry *now_symbol = NULL;

/* Stack */
bool stack[50];
int stack_index = 0;

/* int to str */
void int2str(int i,char *s);
/* float to str */
void float2str(float i, char *s);

/* code generation functions, just an example! */
void insert_var(char *name,char *type,bool assigned);
void assign_var(char *type,char *asgn);
void get_ID();
char calculate();
void postfix(char *type,char *asgn);
void casting(char *type,char *s);
char type_return(char *type);
void return_func(); 
%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */

/* Token without return */
%union {
    int i_val;
    double f_val;
    char* string;
}

/* Token without return */

/* Arithmetic */
%token ADD SUB MUL DIV MOD

/* Relational */
%token MT LT MTE LTE EQ NE

/* Assignment */

/* Logical */
%token AND OR NOT

/* Delimeters */
%token LB RB LCB RCB LSB RSB COMMA

/* Print Keywords*/
%token PRINT 

/* Condition and Loop Keywords */
%token IF ELSE FOR WHILE

/* boolean Keywords */
%token TRUE FALSE
%token RET CONT BREAK

/* String Constant */
%token QUOTA

/* Comment */

/* Variable ID & others */
%token SEMICOLON

/* precedence */
%left EQ NE LT LTE MT MTE
%left ADD SUB
%left MUL DIV MOD
%left INC DEC
%left LB RB

/* Token with return, which need to sepcify type */

%token <i_val> I_CONST
%token <f_val> F_CONST
%token <string> VOID INT FLOAT BOOL STRING ID STR_CONST ASGN ADDASGN SUBASGN MULASGN DIVASGN MODASGN INC DEC
/* Nonterminal with return, which need to sepcify type */
/*
%type <f_val> stat
*/
%type <string> type func_declaration declaration_list assign_operator


/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program
    : statement
    | program statement
    | error ';'
;

declaration
    : type ID SEMICOLON 
    {
	    error = lookup_symbol($2,true,now_level,false); 
	    if(error > 0) 
            strcpy(ID_name,$2);
      	else 
	        insert_var($2,$1,false);   

    }
    | type ID ASGN initializer SEMICOLON 
    {
	    if (error == 0) {
            error = lookup_symbol($2,true,now_level,false); 
            if(error>0) 
                strcpy(ID_name,$2);
            else 
                insert_var($2,$1,true);
      	} 
    }
;

statement
    : if_stat
    | while_stat
    | compound_stat
    | function_stat
    | assign_stat
    | declaration
    | return_stat
    | print_func
;

if_stat
    : IF LB expression RB compound_stat 
    {
        stack_index = 0;
    }
    | IF LB expression RB compound_stat else_stat
    {
        stack_index = 0;
    }
;

expression
    : term MT term
    | term LT term
    | term MTE term
    | term LTE term
    | term EQ term
    {
        if(!stack[stack_index-1] && !stack[stack_index-2] ){
            fprintf(file, "\tisub\n");
            stack[stack_index-2] = false;//int
            stack_index--;
        }else if(!stack[stack_index-1] && !stack[stack_index-2] ){
            fprintf(file, "\tfsub\n");
            stack[stack_index-2] = true;//true
            stack_index--;
        }
    }
    | term NE term
;


else_stat
    : ELSE statement 
;

while_stat
    : WHILE LB operator_stat RB compound_stat
;

function_stat
    : func_def SEMICOLON 
    {
        if(error == 0){
            rear->forward_func = true;
        }else if(error == -1 ){
            error = 4;
        }
        param_i = 0;
        func_error = false;
    }
    | func_def_start stat_list RCB
    {
        Entry *head = front;
        while(head!=NULL) {
            if(!strcmp(head->name,ID_name)) {
                head->forward_func = false;
                break;
            }
            head = head->next;
        }

        fprintf(file, ".end method\n");
    }
    | func_def_start RCB
    {
        Entry *head = front;
        while(head!=NULL) {
            if(!strcmp(head->name,ID_name)) {
                head->forward_func = false;
                break;
            }
            head = head->next;
        }

        fprintf(file, ".end method\n");

    }
    | function_call SEMICOLON
;

func_def_start
    : func_def LCB 
    {
        if(!func_error) {
            for(int i = 0 ; i < param_i ; i++) {
                insert_symbol(-1,param[i],"parameter",param_t[i],now_level,""); 
            }
          }
        param_i=0;
        func_error = false;

        // main function
        if(!strcmp(func_name,"main")) {
            fprintf(file, ".method public static main([Ljava/lang/String;)V\n"
                          ".limit stack 50\n"
                          ".limit locals 50\n");
        }else {
            fprintf(file, ".method public static %s()\n"
                          ".limit stack 50\n"
                          ".limit locals 50\n"
                          ,func_name);
        }

    }
;

func_def
    : type ID LB declaration_list RB
    {
        error = lookup_symbol($2,false,now_level,false); 
        if(error>0) {
            strcpy(ID_name,$2);
            func_error = true;
        }else if (error == 0){
            insert_symbol(-1,$2,"function",$1,now_level,$4); 
        }else {
            strcpy(ID_name,$2);
        }
        bzero(func_name,100);
        strcpy(func_name,$2);
        bzero(func_type,100);
        strcpy(func_type,$1);
    }
    | type ID LB RB
    {
        error = lookup_symbol($2,false,now_level,false); 
        if(error>0) {
            strcpy(ID_name,$2);
            func_error = true;
        }else if (error == 0){
            insert_symbol(-1,$2,"function",$1,now_level,""); 
        }else {
            strcpy(ID_name,$2);
        }

        bzero(func_name,100);
        strcpy(func_name,$2);
        bzero(func_type,100);
        strcpy(func_type,$1);
    }
;

function_call
    : ID LB parameter_list RB  
    {
        error = lookup_symbol($1,false,now_level,true); 
        if(error>0) {
            strcpy(ID_name,$1);
        }
    }  
    | ID LB RB
    {
        error = lookup_symbol($1,false,now_level,true); 
        if(error>0) {
            strcpy(ID_name,$1);
        }
    }
;

return_stat
    : RET SEMICOLON
    {
        return_func();
    }
    | RET operator_stat SEMICOLON
    {
        return_func();
    }
;
    
parameter_list
    : parameter_list COMMA operator_stat
    | operator_stat
;

declaration_list
    : func_declaration
    | declaration_list COMMA func_declaration
    {
        strcat($$,", "); strcat($$, $3);
    }
;

func_declaration
    : type ID 
    {
        $$ = $1;
        strcpy(param_t[param_i],$1);
        strcpy(param[param_i],$2);
        param_i++;

    }
;
compound_stat
    : LCB RCB 
    | LCB stat_list RCB 
;

stat_list
    : statement
    | stat_list statement
;

assign_stat
    : ID assign_operator operator_stat SEMICOLON 
    {
        if(error == 0) {
            error = lookup_symbol($1,true,now_level,true); 
            if(error>0) 
                strcpy(ID_name,$1);
            else 
                assign_var(now_symbol->type,$2);   
        }

    }
    | ID INC SEMICOLON
    { 
        error = lookup_symbol($1,true,now_level,true); 
        if(error>0) 
            strcpy(ID_name,$1);
        else 
            postfix(now_symbol->type,$2);
        
    }
    | ID DEC SEMICOLON 
    { 
        error = lookup_symbol($1,true,now_level,true); 
        if(error>0) 
            strcpy(ID_name,$1);
        else 
            postfix(now_symbol->type,$2);
    }
;

assign_operator
    : ASGN
    | ADDASGN
    | SUBASGN
    | MULASGN
    | DIVASGN
    | MODASGN
;

initializer
    : operator_stat
;

operator_stat
    : operator_stat ADD operator_stat
    {
        char t = calculate();
        fprintf(file, "\t%cadd\n",t);

    }
    | operator_stat SUB operator_stat
    {
        char t = calculate();
        fprintf(file, "\t%csub\n", t);
    }
    | operator_stat MUL operator_stat 
    {         
        char t = calculate();
        fprintf(file, "\t%cmul\n", t);
    }
    | operator_stat DIV operator_stat
    {        
        char t = calculate();
        fprintf(file, "\t%cdiv\n", t);
    }
    | operator_stat MOD operator_stat
    {
        if(!stack[stack_index-1] && !stack[stack_index-2] ){
            fprintf(file, "\tirem\n");
            stack[stack_index-2] = false;//int
            stack_index--;
        }
    }
    | ID INC 
    { 
        if(error == 0) {
            error = lookup_symbol($1,true,now_level,true); 
            if(error>0) {
                strcpy(ID_name,$1);
            }else {
                postfix(now_symbol->type,$2);
                char t = type_return(now_symbol->type);
                fprintf(file, "\t%cload %d\n",t,now_symbol->index);
                stack_index++;
            }
        }
    }
    | ID DEC
    { 
        if(error == 0) {
            error = lookup_symbol($1,true,now_level,true); 
            if(error>0) {
                strcpy(ID_name,$1);
            }else {
                postfix(now_symbol->type,$2);
                char t = type_return(now_symbol->type);
                fprintf(file, "\t%cload %d\n",t,now_symbol->index);
                stack_index++;
            }
        }
    }
    | term
    | STR_CONST
    {
        if(now_level != 0) {
            fprintf(file, "\tldc \"%s\"\n"
                          ,$1);
        }

    }
    | LB operator_stat RB
    | function_call
;

print_func
    : PRINT LB ID RB SEMICOLON 
    { 
        error = lookup_symbol($3,true,now_level,true); 
        if(error>0) {
            strcpy(ID_name,$3);
        }else {
            char t[20] = "";
            if(!strcmp(now_symbol->type,"int") || !strcmp(now_symbol->type,"bool") ) 
                strcpy(t,"I");
            else if(!strcmp(now_symbol->type,"float")) 
                strcpy(t,"F");
            else if(!strcmp(now_symbol->type,"string"))  
                strcpy(t,"Ljava/lang/String;");
            
            get_ID();
            stack_index = 0;

            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                          "\tswap\n"
                          "\tinvokevirtual java/io/PrintStream/println(%s)V\n"
                          ,t);

       }
    }
    | PRINT LB STR_CONST RB SEMICOLON
    {
        
        fprintf(file, "\tldc \"%s\"\n"
                      ,$3);
        fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                      "\tswap\n"
                      "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");

    }
    | PRINT LB I_CONST RB SEMICOLON
    {
        fprintf(file, "\tldc %d\n"
                      ,$3);
        fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                      "\tswap\n"
                      "\tinvokevirtual java/io/PrintStream/println(I)V\n");

    }
    | PRINT LB F_CONST RB SEMICOLON
    {
        fprintf(file, "\tldc %f\n"
                      ,$3);
        fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                      "\tswap\n"
                      "\tinvokevirtual java/io/PrintStream/println(F)V\n");

    }
;

term
    : I_CONST
    {
        if(now_level == 0) 
            global_int = $1;
        else {
            fprintf(file ,"\tldc %d\n",$1);
            stack[stack_index]  = false;
            stack_index++;
        }
    }
    | F_CONST
    {
        if(now_level == 0)
            global_float = $1;
        else {
            fprintf(file ,"\tldc %f\n",$1);
            stack[stack_index]  = true;
            stack_index++;
        
        }
    }
    | ID
    {
        error = lookup_symbol($1,true,now_level,true); 
        if(error != 0)
            strcpy(ID_name,$1);
        else 
            get_ID();

    }
    | TRUE
    {
        if(now_level == 0)
            global_bool = true;
        else 
            fprintf(file, "\tldc 1\n");
    }
    | FALSE
    {
        if(now_level == 0)
            global_bool = false;
        else 
            fprintf(file, "\tldc 0\n");
    
    }
;

/* actions can be taken when meet the token or rule */
type
    : INT
    | FLOAT
    | BOOL 
    | STRING 
    | VOID 
;


%%

/* C code section */

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

    create_symbol();

    file = fopen("compiler_hw3.j","w");

    fprintf(file,   ".class public compiler_hw3\n"
                    ".super java/lang/Object\n");


    yyparse();
    //printf("\nTotal lines: %d \n",yylineno);


    fclose(file);

    return 0;
}

void yyerror(char *s)
{
    syntax_error = true;
/*
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno, buf);
    printf("| %s", s);
    printf("\n| Unmatched token: %s", yytext);
    printf("\n|-----------------------------------------------|\n");
    exit(-1);
*/
}

/* stmbol table functions */
void create_symbol() {
    front = rear = NULL;
}

void insert_symbol(int index,char *name,char *kind,char *type,int scope_level,char *attr ) {
    
    Entry *new;
    new = (Entry*) malloc(sizeof(Entry));
    new->index = index;
    strcpy(new->name,name);
    strcpy(new->kind,kind);
    strcpy(new->type,type);
    new->scope_level=scope_level;
    strcpy(new->attr,attr);
    new->forward_func = false;

    //First node
    if(front == NULL && rear == NULL) {
        new->next = NULL;
        new->prev = NULL;
        front = rear = new;
    }
    else {
        new->prev = rear;
        new->next = NULL;
        rear->next = new;
        rear = new;
    }

}

int lookup_symbol(char *name,bool variable,int scope,bool declare) {
    if(declare) {
        Entry *head = rear;
        while(head!=NULL) {
            if(head->scope_level <= scope && !strcmp(name,head->name)) { 
                now_symbol = head;
                return 0;
            }
            head = head->prev;
        }
        if(variable) {
            return 1;
        }else {
            return 2;
        }
    }else {
        Entry *head = rear;
        while(head!=NULL) {
            if(head->scope_level == scope && !strcmp(name,head->name) ) { 
                
                if(head->forward_func) {
                    return -1;
                }
                else if(variable) {
                    return 3;
                }else {
                    return 4;
                }
            }
            head = head->prev;
        }
    }
    return 0;
}

void del_node(Entry *node) {
    if(node == front && front==rear) {
        front = rear = NULL;
        free(node);
    }else if(node == front) {
        front = node->next;
        front->prev = NULL;
        free(node);
    }else if(node == rear) {
        rear = node->prev;
        rear->next = NULL;
        free(node);
    }else {
        Entry *tmp_f = node->prev,*tmp_r = node->next;
        tmp_f->next = tmp_r;
        tmp_r->prev = tmp_f;
        free(node);
    }
}

void dump_symbol(int scope) {

    Entry *head = front;
    
    while(head!=NULL) {
        
        if(head->scope_level == scope) {
            
            printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
                "Index", "Name", "Kind", "Type", "Scope", "Attribute");
            while(head != NULL && head->scope_level == scope) {
                printf("%-10d%-10s%-12s%-10s%-10d%s\n",head->index,head->name,head->kind,head->type,head->scope_level,head->attr);

                Entry *tmp = head;
                head = head->next;
                del_node(tmp);
                now_index--;
            }
            printf("\n");
            return;
        }
        
        head = head->next;
    }
    return;
}

/* int to string */
void int2str(int i,char *s) {
    sprintf(s,"%d",i);
}
/* float to string */
void float2str(float i, char *s) {
    sprintf(s,"%f",i);
}

/* code generation functions */
void insert_var(char *name,char *type,bool assigned) {
    
    if(now_level == 0) {
        insert_symbol(-1,name,"variable",type,now_level,"");
        char t;
        if(!strcmp(type,"int"))
            t = 'I';
        else if(!strcmp(type,"float"))
            t = 'F';
        else if(!strcmp(type,"bool"))
            t = 'Z';

        if(assigned) {
            switch(t){
                case 'I':
                fprintf(file, ".field public static %s %c = %d\n",name,t,global_int);
                global_int = 0;
                break;
                case 'F':
                fprintf(file, ".field public static %s %c = %f\n",name,t,global_float);
                global_float = 0.0;
                break;
                case 'Z':
                fprintf(file, ".field public static %s %c = %d\n",name,t,global_bool);
                global_bool = 0;
                break;
            }
        } else {
            fprintf(file, ".field public static %s %c\n",name,t);
        }

    }else {
        insert_symbol(now_index,name,"variable",type,now_level,"");
        
        char t = type_return(type);

        if(!assigned) 
            fprintf(file, "\tldc 0\n");

        char s[10] = "";
        casting(type,s);

        fprintf(file, "%s"
                      "\t%cstore %d\n"
                      ,s
                      ,t
                      ,now_index);

        now_index++;
        operator = 0;
        stack_index = 0;
    }

}
void assign_var(char *type,char *asgn) {

    char t = type_return(type);
    char s;
    char to[10] = "";
                
    if(!strcmp(asgn,"=")) {  
    
    }else {
 
        if(stack[stack_index-1]) //float
            s = 'f';
        else //int
            s = 'i';
        
        fprintf(file, "\t%cstore %d\n",s,now_index);
        stack_index--;
        fprintf(file, "\t%cload %d\n",t,now_symbol->index);// load ID     
        stack[stack_index] = (t=='i') ? false : true ;
        stack_index++;
        fprintf(file, "\t%cload %d\n",s,now_index);     
        stack[stack_index] = (s=='i') ? false : true ;
        stack_index++;

        if(!strcmp(asgn,"%=")) { 
            if(!stack[stack_index-1] && !stack[stack_index-2] ){
                fprintf(file, "\tirem\n");
                stack_index--;
            }
        }else {

            char w = calculate();

            char operator[10] = "";//add,sub,mul,div
            switch(asgn[0]) {
                case '+':
                    strcpy(operator,"add");break;
                case '-':
                    strcpy(operator,"sub");break;
                case '*':
                    strcpy(operator,"mul");break;
                case '/':
                    strcpy(operator,"div");break;
            }

            fprintf(file, "\t%c%s\n",w,operator);
        }
    }

    casting(type,to);

    fprintf(file, "%s"
                  "\t%cstore %d\n"
                  ,to
                  ,t
                  ,now_symbol->index);
    operator = 0;
    stack_index = 0;
}

char calculate() {
    char t;
    if(!stack[stack_index-1] && !stack[stack_index-2]) { // int,int
        t = 'i';
        stack[stack_index-2] = false; // int
    }
    else {
        t = 'f';
        if(!stack[stack_index-1] && stack[stack_index-2]) { // int,float
            fprintf(file, "\ti2f\n");
        } else if(stack[stack_index-1] && !stack[stack_index-2]) {// float,int
            fprintf(file, "\tfstore %d\n"
                          "\ti2f\n"
                          "\tfload %d\n"
                          ,now_index,now_index);
                
        }
        stack[stack_index-2] = true; // float
    }
    stack_index -= 1;
    return t; 
}

void postfix(char *type,char *asgn) {

    char t = type_return(type);
    char s[10] = "";
    char postfix[10] = "";

    if(!strcmp(asgn,"++")) 
        strcpy(postfix,"add");
    else 
        strcpy(postfix,"sub");

    if (t == 'f')
        strcpy(s,"\ti2f\n");

    fprintf(file ,"\t%cload %d\n"
                  "\tldc 1\n""%s"
                  "\t%c%s\n"
                  "\t%cstore %d\n"
                  ,t,now_symbol->index
                  ,s
                  ,t,postfix
                  ,t,now_symbol->index);

}
void get_ID() {
    if(now_symbol->index < 0) {
        if(!strcmp(now_symbol->type,"bool")) 
            fprintf(file, "\tgetstatic compiler_hw3/%s Z\n"
                          ,now_symbol->name);
        else 
            fprintf(file, "\tgetstatic compiler_hw3/%s %c\n"
                          ,now_symbol->name
                          ,*(now_symbol->type)-32);

        if(!strcmp(now_symbol->type,"int") || !strcmp(now_symbol->type,"bool")) 
            stack[stack_index]  = false;
        else if(!strcmp(now_symbol->type,"float")) 
            stack[stack_index]  = true;
        
        stack_index++;


    }
    else if(!strcmp(now_symbol->type,"int")) {
        fprintf(file, "\tiload %d\n"
                      ,now_symbol->index);
        stack[stack_index]  = false;
        stack_index++;

    }else if(!strcmp(now_symbol->type,"float")) {
        fprintf(file, "\tfload %d\n"
                      ,now_symbol->index);
        stack[stack_index]  = true;
        stack_index++;
    }else if(!strcmp(now_symbol->type,"string")) {
        fprintf(file, "\taload %d\n"
                      ,now_symbol->index);
    }else if(!strcmp(now_symbol->type,"bool")) {
        fprintf(file, "\tiload %d\n"
                      ,now_symbol->index);
    }


}
void casting(char *type,char *s) {
        
    if(!strcmp(type,"int") && stack[stack_index-1])
        strcpy(s,"\tf2i\n");
    else if(!strcmp(type,"float") && !stack[stack_index-1])
        strcpy(s,"\ti2f\n");

}

char type_return(char *type) {
        char t; 
        if(!strcmp(type,"int") || !strcmp(type, "bool"))
            t = 'i';
        else if(!strcmp(type,"float"))
            t = 'f';
        else if(!strcmp(type,"string"))
            t = 'a';
        return t;
}

void return_func() {

    if(!strcmp(func_type,"void"))
        fprintf(file, "\treturn\n");
    else if(!strcmp(func_type, "int"))
        fprintf(file, "\tireturn\n");
    else if(!strcmp(func_type, "float"))
        fprintf(file, "\tfreturn\n");
    return;

}


