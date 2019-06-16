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

/* int to str */
void int2str(int i,char *s);

/* code generation functions, just an example! */
void gencode_function();

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
%token ADD SUB MUL DIV MOD INC DEC

/* Relational */
%token MT LT MTE LTE EQ NE

/* Assignment */
%token ASGN ADDASGN SUBASGN MULASGN DIVASGN MODASGN

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
%token <string> VOID INT FLOAT BOOL STRING ID STR_CONST

/* Nonterminal with return, which need to sepcify type */
/*
%type <f_val> stat
*/
%type <string> type func_declaration declaration_list

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
	    if(error > 0) {
            strcpy(ID_name,$2);
        }
      	else {
	        
            if(now_level == 0) {
                insert_symbol(-1,$2,"variable",$1,now_level,"");
                char s;
                if(!strcmp($1,"int"))
                    s = 'I';
                else if(!strcmp($1,"float"))
                    s = 'F';
                else if(!strcmp($1,"bool"))
                    s = 'Z';

                fprintf(file, ".field public static %s %c\n",$2,s);

            }else {
                insert_symbol(now_index,$2,"variable",$1,now_level,"");
                fprintf(file, "\tldc 0\n"
                              "\tistore "
                              "%d\n"
                              ,now_index);
                now_index++;
            }            
      	}

    }
    | type ID ASGN initializer SEMICOLON 
    {
	    if (error == 0) {
            error = lookup_symbol($2,true,now_level,false); 
            if(error>0) {
                strcpy(ID_name,$2);
            } else {

	            if(now_level == 0) {
                    insert_symbol(-1,$2,"variable",$1,now_level,"");
                    char s;
                    if(!strcmp($1,"int")){
                    
                        s = 'I';
                        fprintf(file, ".field public static %s %c = %d\n",$2,s,global_int);
                        global_int = 0;

                    } else if(!strcmp($1,"float")) {

                        s = 'F';
                        fprintf(file, ".field public static %s %c = %f\n",$2,s,global_float);
                        global_float = 0;

                    } else if(!strcmp($1,"bool")) {
                
                          s = 'Z';
                          fprintf(file , ".field public static %s %c = %d\n",$2,s,global_bool);
                          global_bool = false;
                    }

                } else {
 
                    insert_symbol(now_index,$2,"variable",$1,now_level,"");
                    
                    if(operator == 1 && !strcmp($1,"float")) {
    
                        fprintf(file, "\ti2f\n");

                    } else if(operator == 2 && !strcmp($1,"int")) {
                    
                        fprintf(file, "\tf2i\n");
                
                    }
                    operator = 0;

                    if(!strcmp($1,"float")) {
                        fprintf(file, "\tfstore %d\n"
                                      ,now_index);
                    } else if(!strcmp($1,"int") || !strcmp($1,"bool")) {
                        fprintf(file, "\tistore %d\n"
                                      ,now_index);
                    } else if(!strcmp($1,"string")) {
                        fprintf(file, "\tastore %d\n"
                                      ,now_index);
                    }
                    now_index++;
                }

            }
      	} else {
    	    
            if(now_level == 0) {
                insert_symbol(-1,$2,"variable",$1,now_level,"");
                char s;
                if(!strcmp($1,"int")){
                
                    s = 'I';
                    fprintf(file, ".field public static %s %c = %d\n",$2,s,global_int);
                    global_int = 0;

                } else if(!strcmp($1,"float")) {
    
                    s = 'F';
                    fprintf(file, ".field public static %s %c = %f\n",$2,s,global_float);
                    global_float = 0;

                }else if(!strcmp($1,"bool")) {
                
                    s = 'Z';
                    fprintf(file , ".field public static %s %c = %d\n",$2,s,global_bool);
                    global_bool = false;
                }

            } else { 
 
                insert_symbol(now_index,$2,"variable",$1,now_level,"");
                
                if(operator == 1 && !strcmp($1,"float")) {

                    fprintf(file, "\ti2f\n");
                
                } else if(operator == 2 && !strcmp($1,"int")) {
                    
                    fprintf(file, "\tf2i\n");
                
                }
                operator = 0;
 
                if(!strcmp($1,"float")) {
                    fprintf(file, "\tfstore %d\n"
                                  ,now_index);
                } else if(!strcmp($1,"int") || !strcmp($1,"bool")) {
                    fprintf(file, "\tistore %d\n"
                                  ,now_index);
                } else if(!strcmp($1,"string")) {
                    fprintf(file, "\tastore %d\n"
                                  ,now_index);
                }
                now_index++;
            }
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
    : IF LB operator_stat RB compound_stat 
    | IF LB operator_stat RB compound_stat else_stat
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
            now_index++;
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
            now_index++;
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
        if(!strcmp(func_type,"void"))
            fprintf(file, "\treturn\n");
    }
    | RET operator_stat SEMICOLON{
        if(!strcmp(func_type, "int"))
            fprintf(file, "\tireturn\n");
        else if(!strcmp(func_type, "float"))
            fprintf(file, "\tfreturn\n");
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
          if(error>0) {
              strcpy(ID_name,$1);
          }
        }
    }
    | ID INC SEMICOLON
    { 
        error = lookup_symbol($1,true,now_level,true); 
        if(error>0) {
            strcpy(ID_name,$1);
        }
    }
    | ID DEC SEMICOLON 
    { 
        error = lookup_symbol($1,true,now_level,true); 
        if(error>0) {
          strcpy(ID_name,$1);
        }
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
        if(operator == 1)
            fprintf(file, "\tiadd\n");
        else if(operator == 2)
            fprintf(file, "\tfadd\n");
    }
    | operator_stat SUB operator_stat
    | operator_stat MUL operator_stat
    {
        fprintf(file, "\timul\n");
    }
    | operator_stat DIV operator_stat
    | operator_stat MOD operator_stat
    | operator_stat MT operator_stat  
    | operator_stat LT operator_stat
    | operator_stat MTE operator_stat
    | operator_stat LTE operator_stat
    | operator_stat EQ operator_stat
    | operator_stat NE operator_stat
    | ID INC 
    { 
        if(error == 0) {
            error = lookup_symbol($1,true,now_level,true); 
            if(error>0) {
                strcpy(ID_name,$1);
            }
        }
    }
    | ID DEC
    { 
        if(error == 0) {
            error = lookup_symbol($1,true,now_level,true); 
            if(error>0) {
                strcpy(ID_name,$1);
            }
        }
    }
    | F_CONST
    {
        if(now_level == 0)
            global_float = $1;
        else {
            
            fprintf(file, "\tldc %f\n"
                          ,$1);
            if(operator == 0)
                operator = 2;
            else if(operator == 1) {
                operator = 2;
                fprintf(file, "\ti2f\n");
            }
        }

    }
    | I_CONST
    {
        if(now_level == 0) 
            global_int = $1;
        else {

            fprintf(file, "\tldc %d\n",
                          $1);
        
            if(operator == 0)
                operator = 1;
            else if(operator == 2)
                fprintf(file, "\ti2f\n");

        }

    }
    | STR_CONST
    {
        if(now_level != 0) {
            fprintf(file, "\tldc \"%s\"\n"
                          ,$1);
        }

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
    | ID
    { 
        if(error == 0) {
            error = lookup_symbol($1,true,now_level,true); 
            if(error>0) {
                strcpy(ID_name,$1);
            }
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
            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                      "\tswap\n");
            
            if(!strcmp(now_symbol->type,"int")) {   
                fprintf(file,  "\tinvokevirtual java/io/PrintStream/println(I)V\n");
            
            } else if(!strcmp(now_symbol->type,"float")) {   
                fprintf(file,  "\tinvokevirtual java/io/PrintStream/println(F)V\n");
            } else if(!strcmp(now_symbol->type,"string")) {   
                fprintf(file, "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        
            }
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

/* int to str */
void int2str(int i,char *s) {
    sprintf(s,"%d",i);
}

/* code generation functions */
void gencode_function() {}
