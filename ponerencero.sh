#/bin/bash
### Script para exportar, lista de productos openerp a lemonpos

### para la corrección de errores
set -e

### variables

#### esto hay que corregirlo, debe de decir el nombre de las computadoras.

lovelia=lovelia-caja
santiago1=santiago1
sangoyo=marco-laptop

### directorio de downloads de la compu, que es de donde proviene el archivo de OpenERP.

### password de la base de datos, el script asume que todos los servidores sql usan el mismo password, aunque se podria preguntar al usuario
### pero es algo que no interesa.

passwordbase=ceftriaxona
base=lemondb
#### las operaciones se llevaran a cabo en el directorio de downloads

##########################################################################################

### checa que los requisitos para correr el script esten completos
### programas necesarios: mysql-client

if
[ -e "/usr/bin/mysql" ];
then
echo "encontrado mysql"
else
read -p "Instala mysql-client antes de proceder" && exit 1
fi

### despliega un menú, con la computadora a checar y enviar el inventario
##limpia pantalla
clear

### Despliega las opciones de computadora para enviar los datos.

# si hay que agregar mas opciones solo es agregarlas.

prompt="Seleccione la computadora para poner el inventario en ceros:"
options=("$lovelia" "$santiago1" "$sangoyo")
#options=("$lovelia" )

PS3="$prompt"

select opt in "${options[@]}" "Salir" ; do
#### para salir con el quit
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

####### escoge la opcion
    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "escogiste $opt que es la opción $REPLY"
        break

### si no esta entre los numeros no funciona
    else
        echo "opción no válida, selecciona un número"

###acaba el if
fi

done


### hace el test de conexión
### requiere de set -e
ping -c 2 $opt && echo "conexion exitosa, continuando" && sleep 2 && clear || { read -p "conexión fallida, revisa que haya comunicación con la computadora" ; exit 1; }


### el for loop solo es por precaucion
### pregunta al usuario por la computadora a enviar.

for (( ; ; ))
do


read -p "Seleccionaste poner en ceros el inveatario de $opt, ¿Estas seguro de esta opción?. Escribe el nombre de la farmacia de donde vas a poner el inventario en cero:
>" CONT

echo -e "\n" #linebreak
	if [ "$CONT" == "$opt" ];
	then
		echo "Borrando los productos" && break
	else
		echo "Corre el programa de nuevo, ten mas cuidado la proxima vez" && exit 1
	fi

done

sleep 2


### abre la conexion a la base de datos y borra los productos.


read -p "Ponga la contraseña de administrador de base de datos" && sleep 1

mysql -h $opt -u root -p <<EOF

USE $base

/* pone los productos en cero */

UPDATE products SET stockqty=0;

EOF

read -p  "Todos los productos actualizados en cero" && sleep 2
clear
