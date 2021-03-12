// Tab Width = 4 spaces

#ifndef DMA_MC_H_INCLUDED
#define DMA_MC_H_INCLUDED


#define DMA_ENABLEss_S	       		0
#define DMA_ENABLEss_M	       		(1 << DMA_ENABLEss_S)

#define DMA_chanel_priority_S      	1
#define DMA_chanel_priority_very_high   	(B11 << DMA_chanel_priority_S)
#define DMA_chanel_priority_high  	(B10 << DMA_chanel_priority_S ) 
#define DMA_chanel_priority_medium  (B01 << DMA_chanel_priority_S ) 
#define DMA_chanel_priority_low  	(B00 << DMA_chanel_priority_S ) 

#define DMA_READ_MODE_S		       	3
#define DMA_READ_MODE_memory_M		(1 << DMA_READ_MODE_S)
#define DMA_READ_MODE_pireper_M		(0 << DMA_READ_MODE_S)

#define DMA_WRITE_MODE_S 		    4
#define DMA_WRITE_MODE_memory_M     (1 << DMA_WRITE_MODE_S)
#define DMA_WRITE_MODE_pireper_M    (0 << DMA_WRITE_MODE_S)

#define DMA_READ_INCREMENT_S 	    5
#define DMA_READ_INCREMENT_M       (1 << DMA_READ_INCREMENT_S)
#define DMA_READ_no_INCREMENT_M    (0 << DMA_READ_INCREMENT_S)

#define DMA_WRITE_INCREMENT_S  		6
#define DMA_WRITE_INCREMENT_M  	(1 << DMA_WRITE_INCREMENT_S)
#define DMA_WRITE_no_INCREMENT_M  	(0 << DMA_WRITE_INCREMENT_S)

#define DMA_READ_SIZE_S  			7
#define DMA_READ_SIZE_byte_M  		(0B00 << DMA_READ_SIZE_S) 	 // байт
#define DMA_READ_SIZE_2byte_M  		(0B01 << DMA_READ_SIZE_S)	 // полуслово
#define DMA_READ_SIZE_4byte_M  		(0B10 << DMA_READ_SIZE_S)	 // слово
#define DMA_READ_SIZE_rez_M  		(0B11 << DMA_READ_SIZE_S) 	 // резерв

#define DMA_WRITE_SIZE_S       		9
#define DMA_WRITE_SIZE_byte_M	    ( 0B00 << DMA_WRITE_SIZE_S)  // байт
#define DMA_WRITE_SIZE_2byte_M	    ( 0B01 << DMA_WRITE_SIZE_S)  // полуслово
#define DMA_WRITE_SIZE_4byte_M	    ( 0B10 << DMA_WRITE_SIZE_S)  // слово
#define DMA_WRITE_SIZE_rez_M	    ( 0B11 << DMA_WRITE_SIZE_S)  // резерв

#define DMA_Read_burst_size_S       11   //Кол-во байт пакетной передачи:   2^Read_burst_size


#define DMA_Write_burst_size_S      14    //Кол-во байт пакетной передачи:   2^Write_burst_size


#define DMA_Read_requets_S      	17    // выбор канала чтения 
#define DMA_Read_requets_Cripto_M   ( 2 << DMA_Read_requets_S ) // chanel 0 - crypto 
#define DMA_Read_requets_UART_A_M   ( 0 << DMA_Read_requets_S ) // chanel 1 - UART_A
#define DMA_Read_requets_UART_B_M   ( 1 << DMA_Read_requets_S ) // chanel 0 - UART_B 

#define DMA_Write_requets_S      	20    // выбор канала Записи 
#define DMA_Write_requets_Cripto_M   ( 2 << DMA_Write_requets_S ) // chanel 0 - crypto 
#define DMA_Write_requets_UART_A_M   ( 0 << DMA_Write_requets_S ) // chanel 1 - UART_A
#define DMA_Write_requets_UART_B_M   ( 1 << DMA_Write_requets_S ) // chanel 0 - UART_B 


#define DMA_Read_ack_ena_S 		    	25
#define DMA_Read_ack_ena_memory_M     	(1 << DMA_Read_ack_ena_S)
#define DMA_Write_ack_ena_S 		    26
#define DMA_Write_ack_ena_memory_M     	(1 << DMA_Write_ack_ena_S)
#define DMA_Irq_ena_S 		    		27
#define DMA_Irq_ena_memory_M     		(1 << DMA_Irq_ena_S)




#ifndef _ASSEMBLER_
    #include <inttypes.h>

    typedef struct
    {
	
		volatile uint32_t DESTINATIONS ;  // 0x00
		volatile uint32_t SOURCE ; 		  // 0x04
		volatile uint32_t BYTE_LEN  ;     // 0x08
	    volatile uint32_t CONFIG ;        // 0x0c
	} DMA_CHANNEL_TypeDef  ;
    
	typedef struct
    { 
	
			  DMA_CHANNEL_TypeDef CHANNELS[4];    //  
			   volatile uint32_t  ConfigStatus ;  // 0x80
			
	} DMA_MC_TypeDef;
#endif


#endif //
