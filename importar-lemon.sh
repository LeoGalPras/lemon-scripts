#/bin/bash
### Script para exportar, lista de productos openerp a lemonpos

### para la corrección de errores
set -e

### variables

#### esto hay que corregirlo, debe de decir el nombre de las computadoras.

lovelia=lovelia-caja
santiago1=santiago1
sangoyo=marco-laptop
antena=192.168.2.30

### directorio de downloads de la compu, que es de donde proviene el archivo de OpenERP.

dirdown=~/downloads/

### nombre del archivo a importar y modificar

nomarchivo=pos.order.csv
manual=corregir-manual.csv

### password de la base de datos, el script asume que todos los servidores sql usan el mismo password, aunque se podria preguntar al usuario
### pero es algo que no interesa.

passwordbase=ceftriaxona
base=lemondb
#### las operaciones se llevaran a cabo en el directorio de downloads

cd $dirdown

##########################################################################################

### checa que los requisitos para correr el script esten completos
### programas necesarios: dos2unix mysql-client

if
[ -e "/usr/bin/dos2unix" ];
then
echo "encontrado dos2unix"
else
read -p "Instala dos2unix antes de proceder" && exit 1
fi


if
[ -e "/usr/bin/mysql" ];
then
echo "encontrado mysql"
else
read -p "Instala mysql-client para proceder" && exit 1
fi



if
[ -e "/usr/bin/soffice" ];
then
echo "encontrado libreoffice"
else
read -p "Se recomienda instalar libreoffice para ver los productos faltantes"
fi


### despliega un menú, con la computadora a checar y enviar el inventario
##limpia pantalla
clear

### Despliega las opciones de computadora para enviar los datos

prompt="Seleccione la computadora para enviar el inventario:"
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

##### borra los archivos anteriores de POS-ORDER.

#if  [ -e "$dirdown/pos-or*" ];
#then
echo "borrando los archivos anteriores, espera"  && rm -rf pos.or*
#fi


for (( ; ; ))
do
echo
sleep 2 && read -p "Por favor entra a OPENERP y  exporta el pedido de venta, recuerda seleccionar la palomita de exportar sólo la selección, solo puedes exportar un archivo a la vez"
	if [ -e "$dirdown/$nomarchivo" ];
	then
	break
	fi
done


#limpia
clear

#### segunda parte del script
##### openerp te da los archivos .csv en formato DOS, lo cual da problemas, hay que convertirlos.
##

#### convierte el archivo a unix
dos2unix -- $nomarchivo

## primera parte importa con cat, luego hasta tail lo que hace es fomatear el archivo para que queden dos columnas
## la parte de sed es para quitar las comillas, y queden solo la separacion por comas

cat  $nomarchivo | rev | cut -d, -f-2 | rev   | tail -n +2 | sed 's/\"//g' > /tmp/$nomarchivo

#### hace que el usuario revise el archivo
read -p "Presiona enter para revisar los códigos de los  productos y las cantidades que se van a importar, por favor revisa que sea correcto contra el ticket:"

cat /tmp/$nomarchivo

## pregunta de nuevo

read -p "Estas seguro de que exportaste el archivo correcto? Presiona s para sí. " -n 1 -r
echo    # nueva linea
if [[ $REPLY =~ ^[Ss]$ ]]
then
    echo
else
echo "Corre el programa de nuevo, ten mas cuidado la proxima vez" && exit 1
fi



#### la siguiente parte importa el archivo importa los productos del programa .csv en una tabla temporal, luego compara esa tabla con la tabla de productos y actualiza
####los prodcutos coincidentes.


### el for loop solo es por precaucion
### pregunta al usuario por la computadora a enviar.

for (( ; ; ))
do
## sintaxis especial para el linebreak
read -p "Seleccionaste enviar el archivo a $opt, ¿Estas seguro de esta opción?. Escribe el nombre de la farmacia a donde lo vas a enviar  para proceder:
>" CONT
echo -e "\n"
	if [ "$CONT" == "$opt" ];
	then
		echo "continuando con la importación, espero que no te hayas equivocado" && break
	else
		echo "Corre el programa de nuevo, ten mas cuidado la proxima vez" && exit 1
	fi

done

sleep 2


### abre la conexion a la base de datos e importa el archivo.
### usa esas opciones para que permita importar desde archivo
# el  output va al csv $manual

mysql -h $opt -u root --password=$passwordbase --local-infile > /tmp/$manual <<EOF

USE $base

/* importa el archivo .csv a sql */
CREATE TABLE IF NOT EXISTS temporal (
codigo bigint(20) NOT  NULL,
cantidad varchar(255) NOT NULL
);

LOAD DATA LOCAL INFILE '/tmp/$nomarchivo' INTO TABLE temporal
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(codigo,cantidad);



/* intento sacar el output para los productos que no existen esto tiene que llegar al usuario*/

/*SELECT *
FROM temporal, products
WHERE products.code = temporal.codigo;*/



/* debe de haber una forma que solucione de una sola vez eso, pero ahi creo otra tabla temporal llamada temporal1 con el valor sumado */

CREATE TABLE temporal1 AS
SELECT products.code, products.stockqty, temporal.codigo, temporal.cantidad + products.stockqty AS total
FROM products
INNER JOIN temporal
ON products.code = temporal.codigo;

ALTER TABLE temporal1
DROP COLUMN stockqty,
DROP code;

/* por que hay que declarar las dos tablas, para que el update funcione */

UPDATE products, temporal1
SET products.stockqty = temporal1.total
WHERE products.code = temporal1.codigo;

/* Luego saca las diferencias de los codigos que son diferentes, para que se actualize manualmente*/

SELECT codigo
/*INTO outfile '/tmp/$manual'*/
FROM temporal
WHERE NOT EXISTS (
	SELECT codigo
	FROM temporal1
	WHERE temporal1.codigo = temporal.codigo );


/* Actualiza la tabla de logs para reflejar los cambios
INSERT INTO `logs`( `userid`, `date`, `time`, `action`) VALUES (1,CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Agregado automaticamente por el programa' )
*/


DROP TABLE temporal1;
DROP TABLE temporal;


EOF



read -p  "productos importados" && sleep 2
clear


### si existe el fichero $manual estonces lo abre con libreoffice
if
[ -e "/tmp/$manual" ];
then
read -p  "Algunos productos no pasaron y deben de ser actualizados manualmente, se le mostrará la lista de los códigos de los productos" && soffice /tmp/$manual
else
read -p "Listo, Gracias" && exit 1
fi





###errores een productos grupo, no se puede actualizar directamente, productos sin codigo. Productos que no existen.
##### Mensaje de error de productos.


#UPDATE
#WHERE
#INNER JOIN products ON temporal.codigo=products.codE

#codigo descartado
#​SELECT  * SUM(products.stockqty + temporal.cantidad)
#FROM    tableName
#GROUP   BY ID

#UPDATE stockqty FROM products where user_id IN

#(
#SELECT codigo,cantidad
#FROM temporal
#INNER JOIN products
#ON products.code=temporal.codigo;)

#SELECT products.code,products.stockqty + temporal.cantidad AS mytotal FROM products a JOIN temporal b ON products.code=temporal.codigo
