-- SQL Avancé : évaluation

-- 1/Vues :
-- Créez une vue qui affiche le catalogue produits. L'id, la référence et le nom des produits, ainsi que l'id et le nom de la catégorie doivent apparaître.

CREATE VIEW V_product_catalogue
AS
SELECT pro_id,pro_ref,pro_name,pro_cat_id,cat_name
FROM products
JOIN categories on pro_cat_id= cat_id


-- 2/Procédures stockées
-- Créez la procédure stockée facture qui permet d'afficher les informations nécessaires à une facture en fonction d'un numéro de commande. Cette procédure doit sortir le montant total de 
-- la commande.

-- Pensez à vous renseigner sur les informations légales que doit comporter une facture.
                    
DELIMITER |

DROP PROCEDURE IF EXISTS facture|
CREATE PROCEDURE facture(
    p_ord_id    int UNSIGNED
)
BEGIN
    DECLARE ord_verif   varchar(50);                
    /* DECLARE total_ord  ; */
    SET ord_verif = (                                                                        -- SET = permet de spécifier les colonnes et les valeurs à mettre à jour dans une table. 
        SELECT ord_id
        FROM orders
        WHERE ord_id = p_ord_id
    );
    IF ISNULL(ord_verif)
    THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "this number doesn't exist";              -- permet de signaler une erreur et d'indiquer un message
    ELSE
        SELECT commande.ord_id AS 'order number',
        commande.ord_order_date AS 'Dated',
        CONCAT(commande.cus_firstname, ' ', commande.cus_lastname, ' à ', commande.cus_city) AS 'Client',
        produits.ode_id AS 'command line',
        CONCAT(produits.pro_ref, ' - ', produits.pro_name, ' - ', produits.pro_color) AS 'Produit',
        produits.ode_quantity AS 'quantity produced',
        CONCAT(ROUND(produits.ode_unit_price, 2), '€') AS 'unit price',                    -- CONCAT = permet de concaténer les valeur de plusieurs colonnes pour ne former qu’1 seule chaîne de caractère
        CONCAT(produits.ode_discount, '%') AS 'discount',
        CONCAT(ROUND(totalcomm.total, 2), '€') AS 'Total'                                  -- ROUND =  permet d’arrondir un résultat numérique
        FROM (
            SELECT *
            FROM orders
            INNER JOIN customers ON ord_cus_id = cus_id
            WHERE ord_id = p_ord_id
        ) commande,
        (
            SELECT *
            FROM orders
            INNER JOIN orders_details ON ord_id = ode_ord_id
            INNER JOIN products ON ode_pro_id = pro_id
            WHERE ord_id = p_ord_id
        ) produits,
        (
            SELECT SUM((ode_quantity*ode_unit_price)*((100-ode_discount)/100)) AS 'total'        -- permet de calculer le total de la commande avec la remise
            FROM orders
            INNER JOIN orders_details ON ord_id = ode_ord_id
            WHERE ord_id = p_ord_id
        ) totalcomm;
        
    END IF;
END |

DELIMITER ;

-- Executé par exemple:
CALL facture(25);

---------------------------------------------

-- Triggers
-- Présentez le déclencheur after_products_update demandé dans la phase 2 de la séance sur les déclencheurs

-- 1/ Créer une table commander_articles constituées de colonnes :

-- Créer une table commander_articles constituées de colonnes :

-- codart : id du produit
-- qte : quantité à commander
-- date : date du jour


DROP TABLE commander_articles;
CREATE TABLE commander_articles (
        codart  int(10) UNSIGNED NOT NULL,
        qte int(5) UNSIGNED,
        date    date NOT NULL,
    CONSTRAINT commander_articles_codart_FK FOREIGN KEY (codart) REFERENCES products(pro_id),
    CONSTRAINT commander_article_PK PRIMARY KEY (codart)
);

-- Créer un déclencheur after_products_update sur la table products : lorsque le stock physique devient inférieur au stock d'alerte, une nouvelle ligne 
-- est insérée dans la table commander_articles.

-- Pour le jeu de test de votre déclencheur, on prendra le produit 8 (barbecue 'Athos') auquel on mettra pour valeur de départ :

-- pro_stock_alert = 5


DELIMITER |

DROP TRIGGER IF EXISTS after_products_update|       -- effacer déclencheur si existe
CREATE TRIGGER after_products_update                -- créer déclencheur
AFTER INSERT                                        -- après insertion
ON products
FOR EACH ROW
BEGIN                                               -- commencer
    DECLARE p_stock int;                            -- déclarer
    DECLARE p_alert int;
    DECLARE p_id    int;
    DECLARE new_qte int;
    DECLARE verif   varchar(50); 
    SET p_stock = NEW.pro_stock;                    -- SET spécifie les colonnes et les valeurs à mettre à jour dans une table.
    SET p_alert = NEW.pro_stock_alert;
    SET p_id = NEW.pro_id;
    IF (p_stock < p_alert)
THEN                                                -- alors
        SET new_qte = p_alert - p_stock;
        SET verif = (
            SELECT codart
            FROM commander_articles
            WHERE codart = p_id
        );

     IF ISNULL(verif)                               -- si null 
        THEN
            INSERT INTO commander_articles          -- insérer dans
            (codart, qte, date)
            VALUES                                  -- valeurs
            (p_id, new_qte, CURRENT_DATE());
        ELSE                                        -- autre
            UPDATE commander_articles               -- mettre à jour
            SET qte = new_qte,
            date = CURRENT_DATE()
            WHERE codart = p_id;
        END IF;
    ELSE                                            -- autre
        DELETE                                      -- effacer
        FROM commander_articles
        WHERE codart = p_id;
    END IF;
END|

DELIMITER ;

-- Pour le jeu de test de votre déclencheur, on prendra le produit 8 (barbecue 'Athos') auquel on mettra les valeurs de stock :
-- 6, 4, 3 puis 6.

SELECT *
FROM commander_articles;

UPDATE products
SET pro_stock = 6
WHERE pro_id = 8;



SELECT *
FROM commander_articles;

UPDATE products
SET pro_stock = 4
WHERE pro_id = 8;


SELECT *
FROM commander_articles;

UPDATE products
SET pro_stock = 3
WHERE pro_id = 8;


SELECT *
FROM commander_articles;

UPDATE products
SET pro_stock = 6
WHERE pro_id = 8;


-------------------------------------------------------------------------
-- Transactions

-- Amity HANNAH, Manageuse au sein du magasin d'Arras, vient de prendre sa retraite. Il a été décidé, après de nombreuses tractations, 
-- de confier son poste au pépiniériste le plus ancien en poste dans ce magasin. Ce dernier voit alors son salaire augmenter de 5% et ses anciens collègues pépiniéristes 
-- passent sous sa direction.

-- Ecrire la transaction permettant d'acter tous ces changements en base des données.

-- La base de données ne contient actuellement que des employés en postes. Il a été choisi de garder en base une liste des anciens collaborateurs de l'entreprise parti en retraite. 
-- Il va donc vous falloir ajouter une ligne dans la table posts pour référencer les employés à la retraite.

-- Décrire les opérations qui seront à réaliser sur la table posts.

-- Ecrire les requêtes correspondant à ces opéarations.

-- Ecrire la transaction



-- 1/ ajouter une ligne dans la table posts

INSERT INTO posts(pos_libelle)
VALUES ('employes_a_la_retraite');


-- 2/Décrire les opérations qui seront à réaliser sur la table posts.

-- dans un premier temps indiquer que Amity HANNAH est bien en retraite:
-- donc il faudra : recherchre Hannah Amity et modifier sa fiche et bien indiqué le magasin d'arras.
-- ensuite modifier son id dans la table employes en cherchant avec son id ou son nom ainsi que la ville d'arras.
-- mettre le pépinériste le plus ancien au poste de manageur donc on doit:
-- trié les employés par date d'ancienneté (emp_enter_date)
-- ensuite modifié son id et indiqué qu'il devient le nouveau manageur.
-- après celà modifier son salaire en indiquant l'augmentation de 5%
-- en allant sur la table employé on rajoute 5% à son salaire.


-- 3/ Les requêtes

START TRANSACTION;
INSERT INTO posts (pos_libelle)                                                                     -- Ajout de la ligne employes à la retraite          
VALUES ('employes_a_la_retraite');
SET @idshop = (select sho_id from shops where sho_city = 'Arras');

SET @idemployes_a_la_retraite = (select pos_id from posts where pos_libelle = 'employes_a_la_retraite');          -- modification de la situation du poste de HANNAH Amity
update employees 
set emp_pos_id = @idemployes_a_la_retraite 
where emp_lastname = 'HANNAH' 
AND  emp_firstname = 'Amity'
AND emp_sho_id = @idshop;

SELECT pos_id                                                                                       -- recherche du poste Pépinériste
FROM posts 
WHERE pos_libelle = 'Pépinieriste';

SELECT *                                                                                            -- recherche de l'employé pépinériste
From Employees
JOIN posts ON emp_pos_id = posts.pos_id
WHERE pos_libelle = 'Pépiniériste' 
AND emp_sho_id = @idshop;

SET @id_new_manager = (SELECT emp_id                                                                -- mise à jour du poste du nouveau manageur
FROM employees 
JOIN posts ON emp_pos_id = posts.pos_id
WHERE pos_libelle = 'Pépiniériste' AND emp_sho_id = @idshop
ORDER BY emp_enter_date
limit 1);

SET @post_id_manager = (SELECT pos_id
FROM posts 
WHERE pos_libelle LIKE '%Manage%'
limit 1);

UPDATE employees                                                                                    -- modification du salaire du nouveau manageur avec une augmentation de 5%
SET 
emp_salary = (emp_salary*1.05),
emp_pos_id = @post_id_manager 
WHERE emp_id = @id_new_manager;

SET @les_pepinieristes = (SELECT pos_id 
FROM posts
WHERE pos_libelle = 'Pépinieriste');

SET @id_new_manager = (SELECT emp_id                                                                -- modification du poste de l'employés Dorian
FROM employees 
WHERE emp_firstname = 'Dorian');

UPDATE employees                                                                                    -- mise en place de la hierarchie pour les pépinéristes
SET 
emp_superior_id = @id_new_manager
WHERE emp_pos_id = @les_pepinieristes;
COMMIT;










