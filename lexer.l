%{
#include "parser.h"
#include "y.tab.h"
#include "mem.h"

#define yywrap()	1

extern int yydebug;

long lineno = 1;
%}

ws	[ \t]+
word	[a-zA-Z_][a-zA-Z_0-9]*
digit	[0-9]
num1	{digit}+\.?([eE][-+]?{digit}+)?
num2	{digit}*\.{digit}+([eE][-+]?{digit}+)?
number	{num1}|{num2}

%%

^{ws}?(\#.*)?\n {
    /* ignore blank line (including comment) */
    ++lineno;
}

{ws} {
    /* ignore white spaces */
}

\#.* {
    /* ignore comment */
}

---+            return TK_LINES;
active		return TK_ACTIVE;
box	        return TK_BOX;
fix		return TK_FIX;
heatflow	return TK_HEATFLOW;
lambda  	return TK_LAMBDA;
rect      	return TK_RECT;
world      	return TK_WORLD;

{number} {
    yylval.val = atof(yytext);
    return TK_NUMBER;
}

:{word} {
    yylval.str = estrdup(yytext);
    return TK_SYMBOL;
}

\*\* {
    return TK_POW;
}

. {
    return yytext[0];
}

\n {
    /* ignore */
    ++lineno;
}

%%